namespace TypeCheck {
    bool isSameClassName(id o, NSString *key) { return (o&&[NSStringFromClass([o class]) compare:key]==NSOrderedSame); }
    bool isNumber(id o) { return o&&isSameClassName(o,@"__NSCFNumber"); }
    bool isBoolean(id o) { return o&&isSameClassName(o,@"__NSCFBoolean"); }
    bool isString(id o) { return o&&(isSameClassName(o,@"NSTaggedPointerString")||isSameClassName(o,@"__NSCFString")); }
    bool isArray(id o) { return o&&(isSameClassName(o,@"__NSArrayM")||isSameClassName(o,@"__NSArrayI")); }
    bool isDictionary(id o) { return o&&(isSameClassName(o,@"__NSDictionaryM")||isSameClassName(o,@"__NSDictionaryI")); }
    bool isMatrix3x3(id o) { return o&&(isArray(o)&&[o count]==9); }
    bool isMatrix4x4(id o) { return o&&(isArray(o)&&[o count]==16); }
    bool isMov(id o) { return o&&isString(o)&&[o hasSuffix:@".mov"]; }
}
