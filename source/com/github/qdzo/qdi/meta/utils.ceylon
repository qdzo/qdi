import ceylon.language.meta {
    type
}
import ceylon.language.meta.declaration {
    OpenType,
    OpenClassType,
    OpenInterfaceType,
    OpenUnion,
    OpenIntersection,
    OpenTypeVariable,
    nothingType
}
import ceylon.language.meta.model {
    Type,
    Class,
    Interface
}
import ceylon.logging {
    Logger,
    logger
}

Logger log = logger(`module`);

shared class Parameter(
        shared String name,
        shared Type<> type,
        shared Boolean defaulted
        )  {
    string => "Parameter(name=``name``, type=``type``, defaulted=``defaulted``)";
}

shared {Parameter*} resolveConstructorParameters<T>(Class<T> t) {
    log.debug(() => "Registry.constructParameters: parameters for class <``t``>");

    assert(exists parameterDeclarations
            = t.defaultConstructor?.declaration?.parameterDeclarations);

    value parameters =  parameterDeclarations.collect((e) {
        log.trace(() => "Registry.constructParameters: parameter-declaration: <``e.openType``>");
        value closedType = resolveOpenType(t, e.openType);
        return Parameter(e.name, closedType, e.defaulted);
    });
    log.debug(() => "Registry.constructParameters: constructed parameters: <``parameters``>");
    return parameters;
}

"Gets container class and open type, which need to resolve"
suppressWarnings("expressionTypeNothing")
shared Type<> resolveOpenType<T>(Class<T> parentClass, OpenType openType) {
    switch(ot = openType)
    case (is OpenClassType) {
        log.debug(() => "resolveOpenType: OpenClassType: <``ot``>");
        value resolvedTypes = resolveOpenTypes(parentClass, ot.typeArgumentList);
        return ot.declaration.classApply<Anything>(*resolvedTypes);
    }
    case (is OpenInterfaceType) {
        log.debug(() => "resolveOpenType: OpenInterfaceType: <``ot``>");
        value resolvedTypes = resolveOpenTypes(parentClass, ot.typeArgumentList);
        return ot.declaration.interfaceApply<Anything>(*resolvedTypes);
    }
    case (is OpenUnion) {
        log.debug(() => "resolveOpenType: OpenUnion: <``ot``>");
        value types = resolveOpenTypes(parentClass, ot.caseTypes);
        assert(nonempty types);
        return types.reduce<Type<>>((p, e) => p.union(e));
    }
    case (is OpenIntersection) {
        log.debug(() => "resolveOpenType: OpenIntersection: <``ot``>");

        value types = resolveOpenTypes(parentClass, ot.satisfiedTypes);
        assert(nonempty types);
        return types.reduce<Type<>>((p, e) => p.intersection(e));
    }
    case (is OpenTypeVariable){
        log.debug(() => "resolveOpenType: OpenTypeVariable: <``ot``>");
        // TODO: add variance checking (Vitaly 27.06.2018)
        if(exists typeVar = parentClass.typeArguments[ot.declaration]) {
            return typeVar;
        }
        throw Exception("Error while trying resolve OpenTypeVariable: "+
        "Haven't such type-var: ``ot.declaration`` in class ``parentClass``");
    }
    case (nothingType) {
        log.debug(() => "resolveOpenType: nothingType");
        return nothing;
    }
}

shared Type<>[] resolveOpenTypes(Class<> parentClass, List<OpenType> openTypes)
        => [for (openType in openTypes) resolveOpenType(parentClass, openType)];

shared Class<T> ->[[Class<Anything>*], [Interface<Anything>*]]
describeClass<T>(Class<T> clazz) {

    value extendedClazzez = getClassHierarchyExceptBasicClasses(clazz);
    value interfaces =  getInterfaceHierarhyExeptBasicTypes(clazz);
    return clazz -> [extendedClazzez, interfaces];
}

shared [Class<>+] basicTypes = [`String`, `Integer`, `Float`, `Boolean`, `Character`, `Basic`, `Object`, `Anything`];
shared Boolean isBasicType(Type<> t) => any { for (bt in basicTypes) t.exactly(bt) };

shared [Interface<>*] getInterfaceHierarhyExeptBasicTypes<T>(Interface<T>|Class<T> ifaceOrClass) {
    if(isBasicType(ifaceOrClass)){
        return empty;
    }
    return getInterfaceHierarhy(ifaceOrClass);
}

shared [Interface<>*] getInterfaceHierarhy<T>(Interface<T>|Class<T> ifaceOrClass) {
    assert(is Interface<>[] ifaces =  ifaceOrClass.satisfiedTypes);
    return concatenate(ifaces, ifaces.flatMap(getInterfaceHierarhy));
}

/*
  describe full-hierarchy from first extended class to Basic class (exclusive)
  <ceylon.language::Basic>
  <ceylon.language::Object>
  <ceylon.language::Anything>
*/
shared [Class<Anything>*]
getClassHierarchyExceptBasicClasses<T>(Class<T> clazz) {

    // Only for Anything class extended-class = null;
    assert(exists extendedClassOpenType = clazz.declaration.extendedType);
    assert(is Class<> extendedClass = resolveOpenType(clazz, extendedClassOpenType));
    if(isBasicType(extendedClass)) {
        log.trace(() => "describeClassHierarchyExceptBasicClass: reached Basic class (or some lower)");
        return empty;
    }
    log.trace(() => "describeClassHierarchyExceptBasicClass:  ``extendedClass``");
    return [extendedClass, *getClassHierarchyExceptBasicClasses(extendedClass)];
}


shared Class<> -> Anything getClassInstancePair<T>(Class<T>|T classOrInstance) {
    if(is Class<T> classOrInstance) {
        return classOrInstance->null;
    }
    assert(is Class<T> clazz = type(classOrInstance));
    return clazz -> classOrInstance;
}

