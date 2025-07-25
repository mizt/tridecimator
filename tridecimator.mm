const bool VERBOSE = false;

#import <Cocoa/Cocoa.h>
#import <simd/simd.h>
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
bool isBoolean(id a) { return isSameClassName(a,@"__NSCFBoolean"); }

class MyVertex;
class MyEdge;
class MyFace;

struct MyUsedTypes: public vcg::UsedTypes<vcg::Use<MyVertex>::AsVertexType,vcg::Use<MyEdge>::AsEdgeType,vcg::Use<MyFace>::AsFaceType> {};

class MyVertex : public vcg::Vertex<MyUsedTypes, vcg::vertex::VFAdj, vcg::vertex::Coord3f, vcg::vertex::Mark, vcg::vertex::Qualityf, vcg::vertex::BitFlags> {
private:
    vcg::math::Quadric<double> q;
public:
    vcg::math::Quadric<double> &Qd() { return q; }
};

class MyEdge : public vcg::Edge< MyUsedTypes> {};

typedef vcg::tri::BasicVertexPair<MyVertex> VertexPair;
class MyFace : public vcg::Face<MyUsedTypes, vcg::face::VFAdj, vcg::face::VertexRef, vcg::face::BitFlags> {};

// the main mesh class
class MyMesh : public vcg::tri::TriMesh<std::vector<MyVertex>, std::vector<MyFace>> {};

class MyTriEdgeCollapse: public vcg::tri::TriEdgeCollapseQuadric<MyMesh, VertexPair, MyTriEdgeCollapse, vcg::tri::QInfoStandard<MyVertex>> {
public:
    typedef vcg::tri::TriEdgeCollapseQuadric<MyMesh, VertexPair, MyTriEdgeCollapse, vcg::tri::QInfoStandard<MyVertex>> TECQ;
    typedef MyMesh::VertexType::EdgeType EdgeType;
    inline MyTriEdgeCollapse(const VertexPair &p, int i, vcg::BaseParameterClass *pp) : TECQ(p,i,pp) {}
};

void tridecimator(std::vector<simd::float3> *vercites, std::vector<simd::uint3> *faces, NSString *params) {
    
    MyMesh mesh;
    MyMesh::VertexIterator vit = vcg::tri::Allocator<MyMesh>::AddVertices(mesh,vercites->size());
    
    for(int n=0; n<vercites->size(); n++) {
        vit[n].P() = vcg::Point3f(
            (*vercites)[n].x,
            (*vercites)[n].y,
            (*vercites)[n].z
        );
    }
    
    for(int n=0; n<faces->size(); n++) {
        vcg::tri::Allocator<MyMesh>::AddFace(
            mesh,
            &vit[(*faces)[n].x],
            &vit[(*faces)[n].y],
            &vit[(*faces)[n].z]
        );
    }
    
    bool debug = false;
    
    float ratio = 0.5;
    
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
    
    
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    if(params) {
        settings = [NSJSONSerialization JSONObjectWithData:[[[NSRegularExpression regularExpressionWithPattern:@"(/\\*[\\s\\S]*?\\*/|//.*)" options:1 error:nil] stringByReplacingMatchesInString:params options:0 range:NSMakeRange(0,params.length) withTemplate:@""] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        
        
        if(isBoolean(settings[@"debug"])) debug = [settings[@"debug"] boolValue];

        if(isNumber(settings[@"ratio"])) ratio = [settings[@"ratio"] floatValue];
        if(isNumber(settings[@"BoundaryQuadricWeight"])) qparams.BoundaryQuadricWeight = [settings[@"BoundaryQuadricWeight"] floatValue];
        if(isBoolean(settings[@"FastPreserveBoundary"])) qparams.FastPreserveBoundary = [settings[@"FastPreserveBoundary"] boolValue];
        if(isBoolean(settings[@"AreaCheck"])) qparams.AreaCheck = [settings[@"AreaCheck"] boolValue];
        if(isBoolean(settings[@"HardQualityCheck"])) qparams.HardQualityCheck = [settings[@"HardQualityCheck"] boolValue];
        if(isNumber(settings[@"HardQualityThr"])) qparams.HardQualityThr = [settings[@"HardQualityThr"] floatValue];
        if(isBoolean(settings[@"HardNormalCheck"])) qparams.HardNormalCheck = [settings[@"HardNormalCheck"] boolValue];
        if(isBoolean(settings[@"NormalCheck"])) qparams.NormalCheck = [settings[@"NormalCheck"] boolValue];
        if(isNumber(settings[@"NormalThrRad"])) qparams.NormalThrRad = [settings[@"NormalThrRad"] floatValue];
        if(isNumber(settings[@"CosineThr"])) qparams.CosineThr = [settings[@"CosineThr"] floatValue];
        if(isBoolean(settings[@"OptimalPlacement"])) qparams.OptimalPlacement = [settings[@"OptimalPlacement"] boolValue];
        if(isBoolean(settings[@"SVDPlacement"])) qparams.SVDPlacement = [settings[@"SVDPlacement"] boolValue];
        if(isBoolean(settings[@"PreserveTopology"])) qparams.PreserveTopology = [settings[@"PreserveTopology"] boolValue];
        if(isBoolean(settings[@"PreserveBoundary"])) qparams.PreserveBoundary = [settings[@"PreserveBoundary"] boolValue];
        if(isNumber(settings[@"QuadricEpsilon"])) qparams.QuadricEpsilon = [settings[@"QuadricEpsilon"] floatValue];
        if(isBoolean(settings[@"QualityCheck"])) qparams.QualityCheck = [settings[@"QualityCheck"] boolValue];
        if(isNumber(settings[@"QualityThr"])) qparams.QualityThr = [settings[@"QualityThr"] floatValue];
        if(isBoolean(settings[@"QualityQuadric"])) qparams.QualityQuadric = [settings[@"QualityQuadric"] boolValue];
        if(isNumber(settings[@"QualityQuadricWeight"])) qparams.QualityQuadricWeight = [settings[@"QualityQuadricWeight"] floatValue];
        if(isBoolean(settings[@"QualityWeight"])) qparams.QualityWeight = [settings[@"QualityWeight"] boolValue];
        if(isNumber(settings[@"QualityWeightFactor"])) qparams.QualityWeightFactor = [settings[@"QualityWeightFactor"] floatValue];
        if(isNumber(settings[@"ScaleFactor"])) qparams.ScaleFactor = [settings[@"ScaleFactor"] floatValue];
        if(isBoolean(settings[@"ScaleIndependent"])) qparams.ScaleIndependent = [settings[@"ScaleIndependent"] boolValue];
        if(isBoolean(settings[@"UseArea"])) qparams.UseArea = [settings[@"UseArea"] boolValue];
        if(isBoolean(settings[@"UseVertexWeight"])) qparams.UseVertexWeight = [settings[@"UseVertexWeight"] boolValue];
    }
    
    if(debug) {
        NSLog(@"ratio = %f",ratio);
        NSLog(@"BoundaryQuadricWeight = %f",qparams.BoundaryQuadricWeight);
        NSLog(@"FastPreserveBoundary = %s",(qparams.FastPreserveBoundary)?"true":"false");
        NSLog(@"AreaCheck = %s",(qparams.AreaCheck)?"true":"false");
        NSLog(@"HardQualityCheck = %s",(qparams.HardQualityCheck)?"true":"false");
        NSLog(@"HardQualityThr = %f",qparams.HardQualityThr);
        NSLog(@"HardNormalCheck = %s",(qparams.HardNormalCheck)?"true":"false");
        NSLog(@"NormalCheck = %s",(qparams.NormalCheck)?"true":"false");
        NSLog(@"NormalThrRad = %f",qparams.NormalThrRad);
        NSLog(@"CosineThr = %f",qparams.CosineThr);
        NSLog(@"OptimalPlacement = %s",(qparams.OptimalPlacement)?"true":"false");
        NSLog(@"SVDPlacement = %s",(qparams.SVDPlacement)?"true":"false");
        NSLog(@"PreserveTopology = %s",(qparams.PreserveTopology)?"true":"false");
        NSLog(@"PreserveBoundary = %s",(qparams.PreserveBoundary)?"true":"false");
        NSLog(@"QuadricEpsilon = %f",qparams.QuadricEpsilon);
        NSLog(@"QualityCheck = %s",(qparams.QualityCheck)?"true":"false");
        NSLog(@"QualityThr = %f",qparams.QualityThr);
        NSLog(@"QualityQuadric = %s",(qparams.QualityQuadric)?"true":"false");
        NSLog(@"QualityQuadricWeight = %f",qparams.QualityQuadricWeight);
        NSLog(@"QualityWeight = %s",(qparams.QualityWeight)?"true":"false");
        NSLog(@"QualityWeightFactor = %f",qparams.QualityWeightFactor);
        NSLog(@"ScaleFactor = %f",qparams.ScaleFactor);
        NSLog(@"ScaleIndependent = %s",(qparams.ScaleIndependent)?"true":"false");
        NSLog(@"UseArea = %s",(qparams.UseArea)?"true":"false");
        NSLog(@"UseVertexWeight = %s",(qparams.UseVertexWeight)?"true":"false");
    }
    
    unsigned int TargetFaceNum = (faces->size()/3.0)*ratio;
    
    if(VERBOSE) printf("mesh loaded %d %d \n",mesh.vn,mesh.fn);
    
    double TargetError = std::numeric_limits<double>::max();
    
    bool CleaningFlag = true;
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
    
    vercites->clear();
    faces->clear();
    
    unsigned int num = 0;
    std::vector<int> indices(mesh.vert.size());
    for(unsigned int n=0; n<mesh.vert.size(); n++) {
        if(!mesh.vert[n].IsD()) {
            indices[n]=num++;
            vercites->push_back(simd::float3{
                mesh.vert[n].P()[0],
                mesh.vert[n].P()[1],
                mesh.vert[n].P()[2]
            });
        }
    }
    
    for(unsigned int n=0; n<mesh.face.size(); n++) {
        if(!mesh.face[n].IsD()) {
            if(mesh.face[n].VN()==3) {
                faces->push_back(simd::uint3{
                    (unsigned int)indices[vcg::tri::Index(mesh,mesh.face[n].V(0))],
                    (unsigned int)indices[vcg::tri::Index(mesh,mesh.face[n].V(1))],
                    (unsigned int)indices[vcg::tri::Index(mesh,mesh.face[n].V(2))]
                });
            }
        }
    }
}