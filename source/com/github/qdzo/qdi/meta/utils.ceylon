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

"Data class for storing constructor parameter info"
shared class Parameter(
        "Class, which constructor have this parameter"
        shared Class<> targetClass,
        "parameter-name in constructor"
        shared String parameterName,
        "parameter-type in constructor"
        shared Type<> parameterType,
        "Is parameter has default value in constructor"
        shared Boolean defaulted
        )  {
    string => "Parameter(targetClass=``targetClass``, name=``parameterName``, type=``parameterType``, defaulted=``defaulted``)";
}

"Try get default-constructor declaration from class declaration,
 Collect parameter-list and resolve them (close type).

 *The hardest part of resolving meta-model*"
shared {Parameter*} resolveConstructorParameters<T>(Class<T> t) {
    log.debug(() => "constructParameters: parameters for class <``t``>");

    assert(exists parameterDeclarations
            = t.defaultConstructor?.declaration?.parameterDeclarations);

    value parameters =  parameterDeclarations.collect((e) {
        log.trace(() => "constructParameters: parameter-declaration: <``e.openType``>");
        value closedType = resolveOpenType(t, e.openType);
        return Parameter(t, e.name, closedType, e.defaulted);
    });
    log.debug(() => "constructParameters: constructed parameters: <``parameters``>");
    return parameters;
}

"Gets container class and open type, which need to resolve.
 Try to resolve open type to closeType"
suppressWarnings("expressionTypeNothing")
see(`function resolveOpenTypes`)
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

"Resolve open types with container class (parentClass)"
see(`function resolveOpenType`)
shared Type<>[] resolveOpenTypes(Class<> parentClass, List<OpenType> openTypes)
        => [for (openType in openTypes) resolveOpenType(parentClass, openType)];

"Get class info:
 - full parent-hierarchy(except basic types)
 - full-set of interfaces, which satisfied by class and it's hierarchy

 Example:

     interface X {}
     interface Y {}
     class A() {}
     class B() satisfied X {}
     class C() extends B() satisfies Y {}
     class B() extends C() {}

     describeClass(`A`) == `A`->[ emptySet, emptySet];
     describeClass(`B`) == `B`->[ emptySet, set{`X`}];
     describeClass(`C`) == `C`->[ set{`B`}, set{`X`, `Y`}];
     describeClass(`D`) == `D`->[ set{`C`, `B`}, set{`X`, `Y`}];
     "
shared Class<T> ->[Set<Class<Anything>>, Set<Interface<Anything>>]
describeClass<T>(Class<T> clazz) {

    value extendedClazzez = getClassHierarchyExceptBasicClasses(clazz);
    value interfaces =  extendedClazzez
        .follow(clazz)
        .flatMap(getInterfaceHierarchyExceptBasicTypes);
    return clazz -> [extendedClazzez, set(interfaces)];
}

"List of ceylon basic-types"
shared [Class<>+] basicTypes = [`String`, `Integer`, `Float`, `Boolean`, `Character`, `Basic`, `Object`, `Anything`];

"Ceylon basic type Predicate"
shared Boolean isBasicType(Type<> t) => any { for (bt in basicTypes) t.exactly(bt) };

"Get set of interfaces satisfied by given class/interface,
  except basic-types interfaces"
see(`value basicTypes`)
see(`function isBasicType`)
shared Set<Interface<>> getInterfaceHierarchyExceptBasicTypes<T>(Interface<T>|Class<T> ifaceOrClass) {
    if(isBasicType(ifaceOrClass)){
        return emptySet;
    }
    return getInterfaceHierarchySet(ifaceOrClass);
}

"Get set of interfaces satisfied by given class/interface"
shared Set<Interface<>> getInterfaceHierarchySet<T>(Interface<T>|Class<T> ifaceOrClass) {
    assert(is Interface<>[] ifaces =  ifaceOrClass.satisfiedTypes);
    return set(ifaces.append(ifaces.flatMap(getInterfaceHierarchySet).sequence()));
}

"Describe full-hierarchy from first extended class to Basic types(exclusive)
"
see(`value basicTypes`)
see(`function isBasicType`)
shared Set<Class<Anything>>
getClassHierarchyExceptBasicClasses<T>(Class<T> clazz) {

    // Only for Anything class extended-class = null;
    assert(exists extendedClassOpenType = clazz.declaration.extendedType);
    assert(is Class<> extendedClass = resolveOpenType(clazz, extendedClassOpenType));
    if(isBasicType(extendedClass)) {
        log.trace(() => "describeClassHierarchyExceptBasicClass: reached Basic class (or some lower)");
        return emptySet;
    }
    log.trace(() => "describeClassHierarchyExceptBasicClass:  ``extendedClass``");
    return set{extendedClass, *getClassHierarchyExceptBasicClasses(extendedClass)};
}


shared Class<> -> Anything getClassInstancePair<T>(Class<T>|T classOrInstance) {
    if(is Class<T> classOrInstance) {
        return classOrInstance->null;
    }
    assert(is Class<T> clazz = type(classOrInstance));
    return clazz -> classOrInstance;
}

