const bool VERBOSE = false;

#import <Cocoa/Cocoa.h>
#import "tridecimator.h"

// stuff to define the mesh
#import <vcg/complex/complex.h>

// local optimization
#import <vcg/complex/algorithms/local_optimization.h>
#import <vcg/complex/algorithms/local_optimization/tri_edge_collapse_quadric.h>

#import <vcg/complex/algorithms/clean.h>

#import <algorithm>

bool isSameClassName(id a, NSString *b) { return (a&&[[a className] compare:b]==NSOrderedSame); }
bool isNumber(id a) { return isSameClassName(a,@"__NSCFNumber"); }

class MyVertex;
class MyEdge;
class MyFace;

struct MyUsedTypes: public vcg::UsedTypes<vcg::Use<MyVertex>::AsVertexType,vcg::Use<MyEdge>::AsEdgeType,vcg::Use<MyFace>::AsFaceType> {};

class MyVertex : public vcg::Vertex<MyUsedTypes,vcg::vertex::VFAdj,vcg::vertex::Coord3f,vcg::vertex::Mark,vcg::vertex::Qualityf,vcg::vertex::BitFlags> {
private:
    vcg::math::Quadric<double> q;
public:
    vcg::math::Quadric<double> &Qd() { return q; }
};

class MyEdge : public vcg::Edge< MyUsedTypes> {};

typedef vcg::tri::BasicVertexPair<MyVertex> VertexPair;
class MyFace : public vcg::Face<MyUsedTypes, vcg::face::VFAdj,vcg::face::VertexRef,vcg::face::BitFlags> {};

// the main mesh class
class MyMesh : public vcg::tri::TriMesh<std::vector<MyVertex>,std::vector<MyFace>> {};

class MyTriEdgeCollapse: public vcg::tri::TriEdgeCollapseQuadric<MyMesh,VertexPair,MyTriEdgeCollapse,vcg::tri::QInfoStandard<MyVertex>> {
public:
    typedef vcg::tri::TriEdgeCollapseQuadric<MyMesh,VertexPair,MyTriEdgeCollapse,vcg::tri::QInfoStandard<MyVertex>> TECQ;
    typedef MyMesh::VertexType::EdgeType EdgeType;
    inline MyTriEdgeCollapse(const VertexPair &p, int i, vcg::BaseParameterClass *pp) : TECQ(p,i,pp) {}
};

void tridecimator(std::vector<float> *v, std::vector<unsigned int> *f, NSString *params) {
    
    MyMesh mesh;
    MyMesh::VertexIterator vit = vcg::tri::Allocator<MyMesh>::AddVertices(mesh,v->size()/3);
    
    for(int n=0; n<v->size()/3; n++) {
        vit[n].P() = vcg::Point3f(
            (*v)[n*3+0],
            (*v)[n*3+1],
            (*v)[n*3+2]
        );
    }
    
    for(int n=0; n<f->size()/3; n++) {
        vcg::tri::Allocator<MyMesh>::AddFace(
            mesh,
            &vit[(*f)[n*3+0]],
            &vit[(*f)[n*3+1]],
            &vit[(*f)[n*3+2]]
        );
    }
    
    float ratio = 0.5;
    
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    if(params) {
        settings = [NSJSONSerialization JSONObjectWithData:[[[NSRegularExpression regularExpressionWithPattern:@"(/\\*[\\s\\S]*?\\*/|//.*)" options:1 error:nil] stringByReplacingMatchesInString:params options:0 range:NSMakeRange(0,params.length) withTemplate:@""] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        if(isNumber(settings[@"ratio"])) ratio = [settings[@"ratio"] floatValue];
    }
    
    unsigned int TargetFaceNum = (f->size()/3.0)*ratio;
    
    if(VERBOSE) printf("mesh loaded %d %d \n",mesh.vn,mesh.fn);
    
    double TargetError = std::numeric_limits<double>::max();
    
    bool CleaningFlag = true;
    
    vcg::tri::TriEdgeCollapseQuadricParameter qparams;
    qparams.BoundaryQuadricWeight = 0.500000;
    qparams.FastPreserveBoundary = false;
    qparams.AreaCheck = false;
    qparams.HardQualityCheck = false;
    qparams.HardQualityThr = 0.100000;
    qparams.HardNormalCheck = false;
    qparams.NormalCheck = false;
    qparams.NormalThrRad = M_PI/2.0;
    qparams.CosineThr = 0.000000; // ~ cos(pi/2)
    qparams.OptimalPlacement = true;
    qparams.SVDPlacement = false;
    qparams.PreserveTopology = false;
    qparams.PreserveBoundary = false;
    qparams.QuadricEpsilon = 1e-15;
    qparams.QualityCheck = true;
    qparams.QualityThr = 0.300000;  // Collapsed that generate faces with quality LOWER than this value are penalized. So higher the value -> better the quality of the accepted triangles
    qparams.QualityQuadric = false; // During the initialization manage all the edges as border edges adding a set of additional quadrics that are useful mostly for keeping face aspect ratio good.
    qparams.QualityQuadricWeight = 0.001000; // During the initialization manage all the edges as border edges adding a set of additional quadrics that are useful mostly for keeping face aspect ratio good.
    qparams.QualityWeight = false;
    qparams.QualityWeightFactor = 100.000000;
    qparams.ScaleFactor = 1.000000;
    qparams.ScaleIndependent = true;
    qparams.UseArea = true;
    qparams.UseVertexWeight = false;
    
    if(CleaningFlag) {
        int dup = vcg::tri::Clean<MyMesh>::RemoveDuplicateVertex(mesh);
        int unref = vcg::tri::Clean<MyMesh>::RemoveUnreferencedVertex(mesh);
        if(VERBOSE) printf("Removed %i duplicate and %i unreferenced vertices from mesh \n",dup,unref);
    }
    
    if(VERBOSE) printf("reducing it to %i\n",TargetFaceNum);
    
    vcg::tri::UpdateBounding<MyMesh>::Box(mesh);
    
    // decimator initialization
    vcg::LocalOptimization<MyMesh> DeciSession(mesh,&qparams);
    
    int t1 = clock();
    DeciSession.Init<MyTriEdgeCollapse>();
    int t2 = clock();
    if(VERBOSE) printf("Initial Heap Size %i\n",int(DeciSession.h.size()));
    
    DeciSession.SetTargetSimplices(TargetFaceNum);
    DeciSession.SetTimeBudget(0.1f); // this allows updating the progress bar 10 time for sec...
    //DeciSession.SetTargetOperations(100000);
    
    if(TargetError<std::numeric_limits<float>::max()) DeciSession.SetTargetMetric(TargetError);
    
    while(DeciSession.DoOptimization()&&mesh.fn>TargetFaceNum&&DeciSession.currMetric<TargetError) {
        if(VERBOSE) printf("Current Mesh size %7i heap sz %9i err %9g \n",mesh.fn, int(DeciSession.h.size()),DeciSession.currMetric);
    }
    
    int t3 = clock();
    if(VERBOSE) printf("mesh %d %d Error %g \n",mesh.vn,mesh.fn,DeciSession.currMetric);
    if(VERBOSE) printf("Completed in (%5.3f+%5.3f) sec\n",float(t2-t1)/CLOCKS_PER_SEC,float(t3-t2)/CLOCKS_PER_SEC);
    
    v->clear();
    f->clear();
    
    unsigned int num = 0;
    std::vector<int> indices(mesh.vert.size());
    for(unsigned int n=0; n<mesh.vert.size(); n++) {
        if(!mesh.vert[n].IsD()) {
            indices[n]=num++;
            v->push_back(mesh.vert[n].P()[0]);
            v->push_back(mesh.vert[n].P()[1]);
            v->push_back(mesh.vert[n].P()[2]);
        }
    }
    
    for(unsigned int n=0; n<mesh.face.size(); n++) {
        if(!mesh.face[n].IsD()) {
            if(mesh.face[n].VN()==3) {
                f->push_back(indices[vcg::tri::Index(mesh,mesh.face[n].V(0))]);
                f->push_back(indices[vcg::tri::Index(mesh,mesh.face[n].V(1))]);
                f->push_back(indices[vcg::tri::Index(mesh,mesh.face[n].V(2))]);
            }
        }
    }
}