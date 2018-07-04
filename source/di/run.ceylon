import ceylon.collection {
    MutableMap,
    HashMap
}
import ceylon.language.meta {
    type
}
import ceylon.language.meta.declaration {
    OpenClassType,
    OpenTypeVariable,
    OpenUnion,
    OpenIntersection,
    OpenType,
    nothingType,
    OpenInterfaceType
}
import ceylon.language.meta.model {
    Type,
    Class,
    Interface,
    UnionType,
    IntersectionType
}
import ceylon.logging {
    Logger,
    logger,
    addLogWriter,
    writeSimpleLog,
    defaultPriority,
    trace
}
import ceylon.test {
    test,
    assertIs,
    assertEquals,
    assertThatException,
    tag,
    beforeTestRun
}

Logger log = logger(`module di`);

beforeTestRun
shared void setupLogger() {
    addLogWriter(writeSimpleLog);
    defaultPriority =
             trace
//             info
    ;
}

// ----------------------------------------------------


class Registry {

//    class RegistryState(
//            shared Map<[Type<>, String],Anything> parameters = emptyMap,
//            shared Map<Type<>, Anything> componentsCache = emptyMap,
//            shared Map<Interface<>, Class<>> interfaceComponents = emptyMap)  {
//
//        shared RegistryState with(
//                Map<[Type<>, String], Anything> parameters = this.parameters,
//                Map<Type<>, Anything> componentsCache = this.componentsCache,
//                Map<Interface<>, Class<>> interfaceComponents = this.interfaceComponents
//                )  => RegistryState(parameters, componentsCache, interfaceComponents);
//
//    }


    class MetaRegistry {

        MutableMap<Class<>, [[Class<>*], [Interface<>*]]>
        components = HashMap<Class<>, [[Class<>*], [Interface<>*]]> {};

        MutableMap<Class<>, Class<>>
        extendComponents = HashMap<Class<>, Class<>> {};

        MutableMap<Interface<>, Class<>>
        interfaceComponents = HashMap<Interface<>, Class<>> {};

        shared new({Class<Anything>*} components = empty) {

            value described = components.collect(describeClass);

            this.components.putAll(described);
            
            this.extendComponents.putAll {
                for (clazz-> [extClazzez, __] in described)
                for(extClazz in extClazzez)
                extClazz -> clazz
            };
            
            this.interfaceComponents.putAll {
                for (clazz->[ __, ifaces] in described)
                for (iface in ifaces)
                iface -> clazz
            };
        }

//        shared Boolean isRegistered<T>(Class<T> clazz) => componentsCache[clazz] exists;
//
        shared [Interface<>*] getClassInterfaces<T>(Class<T> clazz)
                => if(exists [_, ifaces] = components[clazz]) then ifaces else [];

        shared [Class<>*] getClassHierarty<T>(Class<T> clazz)
                => if(exists [classes,_] = components[clazz]) then classes else [];

        shared [[Class<>*], [Interface<>*]] getClassInfo<T>(Class<T> clazz)
                =>  components[clazz] else [empty, empty];

        shared [Class<>*] getAppropriateClassForType<T>(Type<T> t) {
            
            if (is Interface<T> t) {
                log.debug(() => "MetaRegistry.getAppropriateClassForType: <``t``> is a Interface");
                if(is Class<T> satisfiedClass = interfaceComponents.get(t)) {
                    log.debug(() => "MetaRegistry.getAppropriateClassForType: has registered class <``satisfiedClass``> for interface <``t``>");
                    return [satisfiedClass];
                }
                log.warn(() => "MetaRegistry.getAppropriateClassForType: Haven't registered types for interface: <``t``>");
                return empty;
            }

            else if(is Class<T> t) {
                log.debug(() => "MetaRegistry.getAppropriateClassForType: <``t``> is a Class");
                if(is Class<T> extendedClass = extendComponents.get(t)) {
                    log.debug(() => "MetaRegistry.getAppropriateClassForType: has registered type for class <``t``>");
                    return [extendedClass];
                }
                log.warn(() => "MetaRegistry.getAppropriateClassForType: Haven't registered types for class: <``t``>");
                return empty;
            }
           
            else if(is UnionType<T> t) {
                log.debug(() => "MetaRegistry.getAppropriateClassForType: <``t``> is an UnionType");
                return concatenate(t.caseTypes.narrow<Class<>>(), t.caseTypes.flatMap(getAppropriateClassForType));
            }
          
            else if(is IntersectionType<T> t) {
                log.debug(() => "MetaRegistry.getAppropriateClassForType: <``t``> is an IntersectionType");

                value intersected = interfaceComponents
                    .filterKeys((iface) => iface in t.satisfiedTypes)
                    .inverse()
                    .find((clazz -> ifaces) => ifaces.every((iface) => iface in t.satisfiedTypes));

                if(exists intersected,
                    is Class<T> cl = intersected.key) {
                    return [cl];
                }
                log.warn(() => "MetaRegistry.getAppropriateClassForType: Haven't registered types for interface intersection: <``t``>");
                return empty;
            }
            // not found
            log.warn(() => "MetaRegistry.getAppropriateClassForType: Type is not interface nor class: <``t``>");
            return empty;
        }

        shared void registerMetaInfoForType<T>(Class<T> t) {
            log.info("MetaRegistry.describeAndRegisterType: register type <``t``>");
            value clazz->[extClazzez, ifaces] = describeClass(t);
            components.put(clazz, [extClazzez, ifaces]);
            extendComponents.putAll { for (extClazz in extClazzez) extClazz -> clazz };
            interfaceComponents.putAll { for (iface in ifaces) iface -> clazz };
        }

        shared void inspect() {
            print("---------------- META-REGISTRY INSPECTION -----------------");
            printAll({
                "componentsCache size: ``components.size``",
                "interfaceComponents size: ``interfaceComponents.size``",
                "extendComponents size: ``extendComponents.size``"
            }, "\n");
            if (!components.empty) {
                print("------------------ componenets ------------------");
                printAll(components, "\n");
            }
            if (!interfaceComponents.empty) {
                print("------------------ interfacesComponenets ------------------");
                printAll(interfaceComponents, "\n");
            }
            if (!extendComponents.empty) {
                print("-------------------- extendComponents ----------------------");
                printAll(extendComponents, "\n");
            }
            print("------------------------------------------------------------");
        }
    }

    late MetaRegistry metaRegistry;

//    alias ParametersRegistry => Map<[Class<>, String], Anything>;

    MutableMap<[Class<>, String], Anything> parameters
            = HashMap<[Class<>, String], Anything> {};

    MutableMap<Class<>, Anything> componentsCache
            = HashMap<Class<>, Anything> {};

    MutableMap<Interface<>, [Class<>+]> enhancerComponents
            = HashMap<Interface<>, [Class<>+]> {};


    Exception? checkEnhancerInterfaceCompatibility<Target, Wrapper>(
            Type<Target>->[Class<>[], Interface<>[]] targetInfo,
            Class<Wrapper>->[Class<>[], Interface<>[]] wrapperInfo) {

        value targetClassOrIface->[targetExtendClasses, targetInterfaces] = targetInfo;
        value wrapperClass->[wrapperExtendClasses, wrapperInterfaces] = wrapperInfo;

        value targetInterfaceSet =  set (
            [if(is Interface<> iface = targetClassOrIface) iface]
                .append(targetInterfaces)
        );
        value wrapperInterfaceSet = set(wrapperInterfaces);

        log.trace(() =>"Registry.checkEnhancerInterfaceCompatibility: check enhancer " +
                "``wrapperInfo.key`` compatibility with type <``targetInfo.key``>");

        // if target is subset of wrapper -> ok
        if(targetInterfaceSet.subset(wrapperInterfaceSet)) {
            log.trace(() =>"Registry.checkEnhancerInterfaceCompatibility: check passed");
            return null;
        }
        value missed = targetInterfaceSet.complement(wrapperInterfaceSet);

        log.trace(() =>"Registry.checkEnhancerInterfaceCompatibility: check failed, violations: ``missed``");

        return Exception("Enchancer class <``wrapperInfo.key``> not compatible " +
                        "with origin class <``targetInfo.key``>: missed interfaces ``missed``");
    }

    Exception? checkEnhancerConstructorCompatibility<Target, Wrapper>(
            Type<Target>->[Class<>[], Interface<>[]] targetInfo,
            Class<Wrapper>->[Class<>[], Interface<>[]] wrapperInfo) {
        value targetClass->[targetExtendClasses, targetInterfaces] = targetInfo;
        value wrapperClass->[wrapperExtendClasses, wrapperInterfaces] = wrapperInfo;
        
        log.trace(() =>"Registry.checkEnhancerConstructorCompatibility: check enhancer " +
                    "``wrapperClass`` compatibility with type <``targetClass``>");

        value wrapperParams = resolveConstructorParameters(wrapperClass);

        value isThereTargetAsParameter = any {
            for (paramType in wrapperParams*.type)
            paramType in expand {{targetClass}, targetExtendClasses, targetInterfaces}
        };
        if (isThereTargetAsParameter) {
            log.trace(() =>"Registry.checkEnhancerConstructorCompatibility: check passed");
            return null;
        }
        log.trace(() =>"Registry.checkEnhancerConstructorCompatibility: check failed");
        
        return Exception("Enhancer class <``wrapperClass``> must have at least " +
                "one constructor parameter with <``targetClass``> or some of it interfaces ``targetInterfaces``");
    }

    Exception? checkEnchancer<T, W>(Class<T>|Interface<T> target, Class<W> wrapper) {
        value targetInfo =
                if(is Class<T> target)
                then describeClass(target)
                else target->[[], getInterfaceHierarhy(target)];
        
        value wrapperInfo = describeClass(wrapper);

        return checkEnhancerInterfaceCompatibility(targetInfo, wrapperInfo)
               else checkEnhancerConstructorCompatibility(targetInfo, wrapperInfo);
    }

    Exception? checkEnchancers<T>(Class<T>|Interface<T> target, [Class<>+] wrappers) {
        log.debug(() =>"Registry.checkEnchancers: check enhancers ``wrappers`` compatibility with type <``target``>");
        return checkEnchancer(target, wrappers.first)
               else wrappers.paired.map(unflatten(checkEnchancer<Anything, Anything>)).coalesced.first;
    }


    // TODO: Implement registerEnchancer (Vitaly 29.06.2018)
    shared void registerEnchancer<T>(Interface<T> target, [Class<>+] wrappers) {
        log.info("Registry.registerEnchancer: try register enhancers ``wrappers`` for type <``target``>");
        if(is Exception error = checkEnchancers(target, wrappers)) {
            throw error;
        }
        enhancerComponents.put(target, wrappers);
        log.info("Registry.registerEnchancer: register enhancers ``wrappers`` successfully");
    }

    shared void inspect() {
        print("---------------- REGISTRY INSPECTION -----------------");
        printAll({
            "parameters size: ``parameters.size``",
            "componentsCache size: ``componentsCache.size``",
            "enhancerComponents size: ``enhancerComponents.size``"
        }, "\n");
        if (!parameters.empty) {
            print("-------------------- parameters ----------------------");
            printAll(parameters, "\n");
        }
        if (!componentsCache.empty) {
            print("-------------------- componentsCache ----------------------");
            printAll(componentsCache, "\n");
        }
        if (!enhancerComponents.empty) {
            print("-------------------- enhancerComponents ----------------------");
            printAll(enhancerComponents, "\n");
        }
        print("------------------------------------------------------");
        metaRegistry.inspect();
    }

    shared new(
            {Class<>|Object*} components = empty,
            {[Class<>, String, Anything]*} parameters = empty,
            {[Interface<>, [Class<>+]]*} enhancers = empty) {

        value classInstencePairs = components.collect(getClassInstancePair);
        this.componentsCache.putAll(classInstencePairs);
        this.metaRegistry = MetaRegistry(classInstencePairs*.key);
        this.parameters.putAll {
            for ([type, paramName, val] in parameters)
            [type, paramName] -> val
        };

        if(nonempty errors = [*enhancers.map(unflatten(checkEnchancers<Anything>)).coalesced]){
            throw errors.first;
        }
        this.enhancerComponents.putAll {
            for([iface, wrappers] in enhancers)
            if(is Null checkError = checkEnchancers(iface, wrappers))
            iface -> wrappers
        };
    }


    shared void registerParameter<T>(Class<T> t, String param, Anything val) {
        log.info("Registry.registerParameter: for type <``t``>, name: <``param``>, val: <``val else "null"``>");
        parameters.put([t, param], val);
    }

    shared void register<T>(Class<T>|Object typeOrInstance) {
        value clazz->inst = getClassInstancePair(typeOrInstance);
        componentsCache.put(clazz, inst);
        metaRegistry.registerMetaInfoForType(clazz);

        log.info("Registry.register: register " +
                    (if(exists inst) then "instantiated: <``inst``> for " else "") +
                "type <``clazz``>");
    }

    [Class<T>, T|Exception] tryToCreateInstanceIfNotExists<T>([Class<T>, T?] instantiated) {
        value [clazz, instance] = instantiated;
        if(exists instance) {
            return [clazz, instance];
        }
        if(clazz in basicTypes) {
            value errorMsg = "Registry do not create basic types: they should be specified as parameters or created instances basicTypes";
            return [clazz, Exception(errorMsg)];
        }
//        if(clazz.declaration.abstract) {
//            value errorMsg = "Registry do not create ";
//            return [clazz, Exception(errorMsg)];
//        }
        return [clazz, tryToCreateInstance(clazz)];
    }

    T|Exception tryToCreateInstance<T>(Class<T> clazz) {
        try {
            log.debug(() => "Registry.tryToCreateInstance: class <``clazz``>");
            value paramsWithTypes = resolveConstructorParameters(clazz);
            log.trace(() => "Registry.tryToCreateInstance: default constructor for "+
                      "type <``clazz``> has ``paramsWithTypes.size`` parameters");
            value params = instantiateParameters(clazz, paramsWithTypes);
            log.trace(() => "Registry.tryToCreateInstance: try to instantiate type <``clazz``> with params: <``params``>");
            value instance = clazz.namedApply(params);
            log.debug(() => "Registry.tryToCreateInstance: instantiated created for type <``clazz``>");
            return instance;
        } catch(Exception th) {
            value errorMsg = "Can't create instantiated: ``th.message``";
            log.error(() => "Registry.tryToCreateInstance: ``errorMsg``");
            return Exception(errorMsg);
        }
    }


    T|Exception returnInstanceOrException<T>(Type<T> requestedType)([Class<T>, T|Exception] instantiated)  {
        value [clazz, instance] = instantiated;
        return instance;
    }

    [Class<T>, T|Exception] wrapClassWithEnchancer<T>(Type<T> requestedType)([Class<T>, T|Exception] instantiated)  {
        value [clazz, instanceOrException] = instantiated;
        if(is T instance = instanceOrException) {
            log.debug(() => "Registry.wrapClassWithEnchancer: instance <``instance else "null"``> created for type <``clazz``>");
            print(requestedType);
            value enhancers = enhancerComponents.getOrDefault(requestedType, empty);
            if(nonempty enhancers) {
                log.debug(() => "Registry.wrapClassWithEnchancer: has registered enhancers for type <``clazz``>: ``enhancers``");
                variable T wrapped = instance;
                for (e in enhancers) {
                    value params = resolveConstructorParameters(e);
                    value [instanceParam, otherParams] = splitByFilter(params, (Parameter p) => p.type.typeOf(instance));
                    value instantiatedOtherParams = instantiateParameters(e, otherParams);

                    value fullParams = expand {
                        instantiatedOtherParams,
                        instanceParam.map(bindParameterWithValue(wrapped))
                    };
                    assert(is T newWrapped = e.namedApply(fullParams));
                    log.trace(() => "Registry.wrapClassWithEnchancer: create wrapper <``e``> for type <``clazz``>");
                    wrapped = newWrapped;
                }
//                assert(is Target wrapped);
                log.debug(() => "Registry.wrapClassWithEnchancer: instance of <``clazz``> successfully wrapped");
                return [clazz, wrapped];
            }
        }
        log.debug(() => "Registry.wrapClassWithEnchancer: hasn't registered enhancers for type <``clazz``>:");
        return instantiated;
    }

    [{Entity*}, {Entity*}] splitByFilter<Entity>(
            {Entity*} coll, Boolean pred(Entity p))
            => [ coll.filter(pred), coll.filter(not(pred)) ];

    String->T bindParameterWithValue<T>(T val)(Parameter param)
            => param.name->val;

    T? tryFindAndGetApproproateInstance<T>(Type<T> t) {
        log.debug(() => "Registry.tryFindAndGetApproproateInstance: for type <``t``> ");
        value appropriateClasses = expand {
            [if(is Class<T> t, !t.declaration.abstract) t],
            metaRegistry.getAppropriateClassForType(t)
        };

        value firstPotentiallyCreated =
                appropriateClasses
                    .map(getFromCache)
                    .map(tryToCreateInstanceIfNotExists)
                    .map(saveToCache)
                    .map(wrapClassWithEnchancer<Anything>(t))
                    .map(returnInstanceOrException<Anything>(t))
                    .find(notException);

        if(is T i = firstPotentiallyCreated) {
            return i;
        }
        log.warn(() => "Registry.tryFindAndGetApproproateInstance: can't get instantiated: for type ``t``");
        return null;
    }

    Boolean  notException(Anything instanceOrException)
            => !instanceOrException is Exception;

    T cast<T>(Anything val){
        assert(is T val);
        return val;
    }

    [Class<T>, T?] getFromCache<T>(Class<T> clazz) {
        log.debug(() => "Registry.getFromCache: called with class <``clazz``>");
        if (exists instance = componentsCache[clazz]) {
            log.debug(() => "Registry.getFromCache: <``clazz``> has cached value");
            return [clazz, cast<T>(instance)];
        }
        else {
            log.debug(() => "Registry.getFromCache: <``clazz``> hasn't cached value");
            return [clazz, null];
        }
    }



    [Class<T>, T|Exception] saveToCache<T>([Class<T>, T|Exception] instantiated) {
        log.debug(() => "Registry.saveToCache: called with params <``instantiated``>");
        value [clazz, instance] = instantiated;
        if(!is Exception instance,
           !componentsCache[clazz] exists) {
            log.debug(() => "Registry.saveToCache: there are no cached value for <``instantiated``>. cache it!");
            componentsCache.put(clazz, instance);
        }
        return instantiated;
    }

//    - [[ClassOrInterface]]
//    - [[ClassOrInterface]]
//    - [[UnionType]]
//    - [[IntersectionType]]

    shared T getInstance<T>(Type<T> t) {
        log.info(() => "Registry.getInstance: for type <``t``>");
        if(exists i = tryFindAndGetApproproateInstance(t)) {
            return i;
        }
        throw Exception("Registry.getInstance: can't createInstance for class <``t``>");
    }

    [<String->Anything>*]
    instantiateParameters<T>(Class<T> t, {Parameter*} paramsTypes) {
        log.debug(() => "Registry.instantiateParameters: try to instantiate params: ``paramsTypes``");
        return paramsTypes.map(instantiateParameter(t)).coalesced.sequence();
    }

    <String->Anything>? instantiateParameter<T>(Class<T> t)(Parameter parameter) {
        if(exists paramVal = parameters[[t, parameter.name]]) {
            log.trace(() => "Registry.instantiateParameter: found registered parameter for : [``t``,``parameter.name``]");
            return parameter.name -> paramVal;
        } else {
            log.trace(() => "Registry.instantiateParameter: try to initiate parameter <``parameter.name``> needed for class <``t``>");
            value closeType = parameter.type;
            value depInstance = tryFindAndGetApproproateInstance(closeType);
            if(exists depInstance) {
                log.trace(() => "Registry.instantiateParameter: parameter <``parameter.name``> initialized");
                return parameter.name -> depInstance;
            }
            log.trace(() => "Registry.instantiateParameter: parameter <``parameter.name``>(``t``) NOT initialized.");
            if(parameter.defaulted) {
                log.trace(() => "Registry.instantiateParameter: parameter <``parameter.name``>(``t``) has default value in class.");
                return null;
            }
            throw Exception("Unresolved dependency <``parameter.name``> (``parameter.type``) for class <``t``>");
        }
    }

}

class Parameter(
        shared String name,
        shared Type<> type,
        shared Boolean defaulted
        )  {
    string => "Parameter(name=``name``, type=``type``, defaulted=``defaulted``)";
}

{Parameter*} resolveConstructorParameters<T>(Class<T> t) {
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
Type<> resolveOpenType<T>(Class<T> parentClass, OpenType openType) {
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

Type<>[] resolveOpenTypes(Class<> parentClass, List<OpenType> openTypes)
        => [for (openType in openTypes) resolveOpenType(parentClass, openType)];

// TODO move to reflectionTools.ceylon file
Class<T> ->[[Class<Anything>*], [Interface<Anything>*]]
describeClass<T>(Class<T> clazz) {

    value extendedClazzez = getClassHierarchyExceptBasicClasses(clazz);
    value interfaces =  getInterfaceHierarhyExeptBasicTypes(clazz);
    return clazz -> [extendedClazzez, interfaces];
}

[Class<>+] basicTypes = [`String`, `Integer`, `Float`, `Boolean`, `Character`, `Basic`, `Object`, `Anything`];
Boolean isBasicType(Type<> t) => any { for (bt in basicTypes) t.exactly(bt) };

[Interface<>*] getInterfaceHierarhyExeptBasicTypes<T>(Interface<T>|Class<T> ifaceOrClass) {
    if(isBasicType(ifaceOrClass)){
        return empty;
    }
    return getInterfaceHierarhy(ifaceOrClass);
}
[Interface<>*] getInterfaceHierarhy<T>(Interface<T>|Class<T> ifaceOrClass) {
    assert(is Interface<>[] ifaces =  ifaceOrClass.satisfiedTypes);
    return concatenate(ifaces, ifaces.flatMap(getInterfaceHierarhy));
}

/*
  describe full-hierarchy from first extended class to Basic class (exclusive)
  <ceylon.language::Basic>
  <ceylon.language::Object>
  <ceylon.language::Anything>
*/
[Class<Anything>*]
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


Class<> -> Anything getClassInstancePair<T>(Class<T>|T classOrInstance) {
    if(is Class<T> classOrInstance) {
        return classOrInstance->null;
    }
    assert(is Class<T> clazz = type(classOrInstance));
    return clazz -> classOrInstance;
}

// ========================= DESCRIBE-FUNCTIONS TESTS ==========================

test
shared void describeClass_SouldReturnCorrectInfo_ForClassWithMultiInterfaces() {
    value actual = describeClass(`RuPostman`);
    assertEquals(actual, `RuPostman`->[[], [`Postman`, `Operator`]]);
}

class One() { }
class OneOne() extends One() { }
class OneOneOne() extends OneOne() { }

test
shared void describeClassHierarhy_SouldReturnCorrectInfo_ForClassWithSeveralLevelInheritance() {
    value actual = getClassHierarchyExceptBasicClasses(`OneOneOne`);
    assertEquals(actual, [`OneOne`, `One`]);
}

interface A {}
interface B {}
interface C {}
interface AB satisfies A & B {}
interface ABC satisfies AB & C {}
class Clazz() satisfies ABC { }

test
shared void describeClassInterfaces_SouldReturnCorrectInfo_ForClassWithSeveralNestedInterfaces() {
    value actual = getInterfaceHierarhy(`Clazz`);
    assertEquals(actual, [`ABC`, `AB`, `C`, `A`, `B`]);
}

// ------------------ MAIN TESTS ------------------------

class Person(shared String name, shared Integer age)  {
    string = "Person(name = ``name``, age = ``age``)";
}

class Atom() { string = "Atom()"; }

class Atom1 {
    shared new () {}
    string = "Atom1()";
}

class Atom2(shared Integer i) { string = "Atom2(``i``)"; }

class Box(shared Atom atom)  {
    string = "Box(atom = ``atom``)";
}

class Box1  {
    shared Atom atom;
    shared new (Atom atom) { this.atom = atom; }
    string = "Box(atom = ``atom``)";
}

class Box2(shared Atom2 atom = Atom2(2))  {
    string = "Box(atom = ``atom``)";
}
// ----------------------------------------------------
test
shared void registryShouldRegisterType_whenRegisterCalled() {
    value registry = Registry();
    registry.register(`Atom`);
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterType_whenRegistryInitiatedWithParams() {
    value registry = Registry {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterParams_whenRegistryInitiatedWithParams() {
    value registry = Registry {
        components = {`Box`};
        parameters = {[`Box`, "atom", Atom()]};
    };
    assertIs(registry.getInstance(`Box`), `Box`);
}

test
shared void registryShouldCreateInstance_ForTypeWithoutParameters() {
    value registry = Registry {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithoutParameters() {
    value registry = Registry {`Atom1`};
    assertIs(registry.getInstance(`Atom1`), `Atom1`);
}


test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithOneParameter() {
    value registry = Registry {`Atom`, `Box1`};
    assertIs(registry.getInstance(`Box1`), `Box1`);
}

test
shared void registryShouldCreateInstance_WithOneRegisteredDependencyType() {
    value registry = Registry();
    registry.register(`Atom`);
    registry.register(`Box`);
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCall() {
    value registry = Registry();
    registry.register(Box(Atom()));
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInConstuctor() {
    value registry = Registry { Box(Atom()) };
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldCreateInstanceWithSomeSimpleParameters() {
    value registry = Registry { `Person` };
    registry.registerParameter(`Person`, "name", "Vika");
    registry.registerParameter(`Person`, "age", 1);
    value person = registry.getInstance(`Person`);
    assertIs(person, `Person`);
    assertEquals(person.name, "Vika");
    assertEquals(person.age, 1);
}

test
shared void registryShouldThrowExceptinWhenThereAreNoSomeParameters() {
    value registry = Registry { `Person` };
    registry.registerParameter(`Person`, "age", 1);
    assertThatException(() => registry.getInstance(`Person`))
        .hasMessage("Registry.getInstance: can't createInstance for class <di::Person>");
}

tag("default")
test
shared void registryShouldCreateInstanceWithDefaultParameter() {
    value registry = Registry {`Box2`};
    assertIs(registry.getInstance(`Box2`), `Box2`);
}

//------------------------ NESTED DEPENDENCY TESTS -------------------------------

class Matryoshka1(Matryoshka2 m2)  {
    string = "Matryoshka1(m2 = ``m2``)";
}

class Matryoshka2(Matryoshka3 m31, Matryoshka3 m32)  {
    string = "Matryoshka2(m3 = ``m31``, m3 = ``m32``)";
}

class Matryoshka3(Matryoshka0 m01, Matryoshka0 m02, Matryoshka0 m03)  {
    string = "Matryoshka3(m3 = ``m01``, m3 = ``m02``, m3 = ``m03``)";
}

class Matryoshka0()  {
    string = "Matryoshka0()";
}

test
shared void registryShouldCreateDeeplyNestedInstances() {
    value registry = Registry { `Matryoshka0`, `Matryoshka1`, `Matryoshka2`, `Matryoshka3` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

test
shared void registryShouldCreateDeeplyNestedInstancesWithDirectRefenecesAndWithoutExplicitRegistration() {
    value registry = Registry { `Matryoshka1` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

// ============================ CASE CLASS ================================

abstract class Fruit() of orange | apple { }
object apple extends Fruit() {}
object orange extends Fruit() {}

test
shared void registryShouldReturnInstanceForCaseClasses() {
    value registry = Registry { apple };
    value actual = registry.getInstance(`Fruit`);
    assertEquals(actual, apple);
}

test
shared void registryShouldReturnInstanceForCaseClasses1() {
    value registry = Registry { `Fruit` };
    value actual = registry.getInstance(`Fruit`);
    assertEquals(actual, apple);
}

// ============================ UNION TYPE ================================

class Street() { }
class Address(String|Street street) { }

test
shared void registryShouldCreateInstanceWithUnionTypeDependency() {
    value registry = Registry { `Street`, `Address` };
    value actual = registry.getInstance(`Address`);
    assertIs(actual, `Address`);
}

// ============================ INTERSECTION TYPES ================================

interface Postman { }
interface Operator { }
class RuPostman() satisfies Postman & Operator { }
class AsiaPostman() satisfies Postman { }
class RuPostal(shared Postman postman) { }
class RuPostalStore(shared Postman & Operator employee) { }
class AsiaPostal(shared Postman postman = AsiaPostman()) { }



test
shared void registryShouldCreateInstanceWithIntersectionTypeDependency() {
    value registry = Registry { `RuPostalStore`, `RuPostman`, `AsiaPostman` };
    value actual = registry.getInstance(`RuPostalStore`);
    assertIs(actual, `RuPostalStore`);
}

// ============================ GENERIC TYPES ================================


class GenericBox<T>(shared T t)  { }
class GenericTrackCar<T>(shared GenericBox<T> box)  { }
class GenericTanker<T,V>(GenericBox<T> box1, GenericBox<V> box2)  { }

tag("generic")
test
shared void registryShouldCreateInstanceWithOneGenericTypeDependency() {
    value registry = Registry { `GenericTrackCar<String>`, `GenericBox<String>`, "String item" };
    value actual = registry.getInstance(`GenericTrackCar<String>`);
    assertIs(actual, `GenericTrackCar<String>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependency() {
    value registry = Registry {
        `GenericTanker<String, Integer>`,
        `GenericBox<String>`,
        `GenericBox<Integer>`,
        "String item",
        101
    };
    value actual = registry.getInstance(`GenericTanker<String, Integer>`);
    assertIs(actual, `GenericTanker<String, Integer>`);
}

class StringBox(String data) extends GenericBox<String>(data) { }
class StringBox2(String data) extends StringBox(data) { }
class IntegerBox(Integer data) extends GenericBox<Integer>(data) { }

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependencyAndExtendedClasses() {
    value registry = Registry {
        `GenericTanker<String, Integer>`,
        `StringBox`,
        `IntegerBox`,
        "String item",
        101
    };
    value actual = registry.getInstance(`GenericTanker<String, Integer>`);
    assertIs(actual, `GenericTanker<String, Integer>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependencyAndExtendedClasses2() {
    value registry = Registry {
        `GenericTanker<String, Integer>`,
        `StringBox2`,
        `IntegerBox`,
        "String item",
        101
    };
    value actual = registry.getInstance(`GenericTanker<String, Integer>`);
    assertIs(actual, `GenericTanker<String, Integer>`);
}

class IntegerTanker(IntegerBox box1, IntegerBox box2) extends GenericTanker<Integer, Integer>(box1, box2) { }

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependencyAndExtendedClasses3() {
    value registry = Registry {
        `IntegerTanker`,
        `StringBox`,
        `IntegerBox`,
        "String item",
        101
    };
    value actual = registry.getInstance(`IntegerTanker`);
    assertIs(actual, `IntegerTanker`);
}
// ============================ GENERIC TYPES WITH VARIANCES ================================

class Bike() { }
class CrossBike() extends Bike() { }
class ElectroBike() extends CrossBike() { }

class CrossBykeParking(CrossBike bike)  { }
//
class BikeBox<BikeType>(BikeType bike)  { }

// invariant or CONTRvariant
class Bicycler<BikeType>(BikeType bike)  {
    shared void tryBike(BikeType bike) {}
}

// invariant or covariant
class BikeSeller<BikeType>(BikeType bike)  {
    shared BikeType sell(Integer money) => bike;
}

//tag("repl")
test
shared void registryShouldCreateInstanceWithInvariantDependency() {
    value registry = Registry {
        `Bicycler<CrossBike>`,
        `CrossBike`
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

tag("repl")
test
shared void registryShouldCreateInstanceWithoutRegistrationIfWeHaveDirectReferenceToClass() {
    value registry = Registry {
        `Bicycler<CrossBike>`// It's wonderfull - that we can create instances without registering it (if we have direct reference in constructor to classes and if they have default parameters)
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithExtendedTypeDependency() {
    value registry = Registry {
        `Bicycler<CrossBike>`,
        `ElectroBike`
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

// ============================ INTERFACE TESTS ================================


tag("if")
test
shared void registryShouldCreateInstanceWithInterfaceDependency() {
    value registry = Registry {`RuPostman`, `RuPostal`};
    value postal = registry.getInstance(`RuPostal`);
    assertIs(postal, `RuPostal`);
    assertIs(postal.postman, `RuPostman`);
}

tag("if")
test
shared void registryShouldCreateInstanceForGivenInterface() {
    value registry = Registry {`RuPostman`};
    value postman = registry.getInstance(`Postman`);
    assertIs(postman, `RuPostman`);
}

tag("if")
//tag("default")
test
shared void registryShouldCreateInstanceForGivenInterfaceWithItsDefaultParameter() {
    value registry = Registry {`AsiaPostal`};
    assertIs(registry.getInstance(`AsiaPostal`), `AsiaPostal`);
}

tag("if")
test
shared void registryShouldReturnSameInstanceForGivenTwoInterfaces() {
    value registry = Registry {`RuPostman`};
    value postman = registry.getInstance(`Postman`);
    value operator = registry.getInstance(`Operator`);
    assertIs(postman, `RuPostman`);
    assertIs(operator, `RuPostman`);
    assertEquals(postman, operator);
}

// ========================= ABSTRACT TYPES ==========================

abstract class Animal() {}
class Dog() extends Animal() {}
class Cat() extends Animal() {}


tag("abstract")
test
shared void registryShouldCreateInstanceForAbstractClass() {
    value registry = Registry {`Dog`};
    value animal = registry.getInstance(`Animal`);
    assertIs(animal, `Dog`);
}

// ========================= ENCHANCERS ==========================

interface Service {
    shared formal String connection;
}

class DbService(String dbName) satisfies Service {
    connection = dbName;
}

class ServiceDbSchemaDecorator(Service service, String dbType) satisfies Service {
    connection => "``dbType``://" + service.connection;
}

class ServiceDbCredetionalsDecorator(
        Service service,
        String user,
        String password)
        satisfies Service {
    connection => "``user``:``password``@" + service.connection;
}

class FakeDecorator() { }
class FakeDecorator2() satisfies Service {
    shared actual String connection => "connection";
}

tag("enhancer")
test
shared void registryShouldCreateInstanceWithGivenEnchancer() {
    value registry = Registry {`DbService`, "users"};
    registry.registerEnchancer(`Service`, [`ServiceDbSchemaDecorator`]);
    value service = registry.getInstance(`Service`);
    assertIs(service, `ServiceDbSchemaDecorator`);
    assertEquals(service.connection, "users://users");
}

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface() {
    value registry = Registry {`Service`, "users"};
    assertThatException(() => registry.registerEnchancer(`Service`, [`FakeDecorator`]))
    .hasMessage("Enchancer class <di::FakeDecorator> not compatible with origin class <di::Service>: missed interfaces { di::Service }");
}

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface2() {
    value registry = Registry {`DbService`, "users"};
    assertThatException(() => registry.registerEnchancer(`Service`, [`FakeDecorator2`]))
    .hasMessage("Enhancer class <di::FakeDecorator2> must have at least one constructor parameter with <di::Service> or some of it interfaces []");
}

tag("now")
tag("enhancer")
test
shared void registryShouldCreateInstanceWithTwoGivenEnchancers() {
    value registry = Registry {
        components = { DbService("users") };
        enhancers = {
            [`Service`, [ `ServiceDbCredetionalsDecorator`, `ServiceDbSchemaDecorator` ]]
        };
        parameters = {
            [`ServiceDbCredetionalsDecorator`, "user", "qdzo"],
            [`ServiceDbCredetionalsDecorator`, "password", "secret"],
            [`ServiceDbSchemaDecorator`, "dbType", "inmemory"]
        };
    };
    value service = registry.getInstance(`Service`);
    assertIs(service, `ServiceDbSchemaDecorator`);
    assertEquals(service.connection, "inmemory://qdzo:secret@users");
}

