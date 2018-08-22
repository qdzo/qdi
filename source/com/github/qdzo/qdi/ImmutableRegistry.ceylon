import ceylon.language.meta.model {
    Type,
    Class,
    Interface
}
import ceylon.logging {
    Logger,
    logger
}

import com.github.qdzo.qdi.meta {
    describeClass,
    MetaRegistry,
    resolveConstructorParameters,
    basicTypes,
    Parameter,
    getInterfaceHierarchySet,
    getClassInstancePair
}


Logger log = logger(`module`);

// ----------------------------------------------------


"Component - declaration of non abstract class, or pure instance"
shared alias Component =>  Class<>|Object;


"Direct parameters for custom classes.
 Shape: [class-for-injection, constructor-parameter-name, value-to-inject]"
shared alias ParameterForInjection => [Class<>, String, Anything];


"Enchancers-declaration is tuple of shape `[target-interface-to-wrap, [enhancer-list]]`
 
 Enchancer in it's own way is simple wrapper class, that satisfy two constrains:

 - it implements interface which it wraps
 - it consumes interface which it wraps as constructor argument

 > Enchancers are used as adhoc AOP."
shared alias EnchancersDeclaration => [Interface<>, [Class<>+]];

"Immutable Registry - is container that stores information
 about classes, enhancers, parameters and can instantiate them later.

 Every register-method call returns new Registry with additional components/enhancers.
 Old Registry stays the same.

 > This way give you flexibility of creating separated registries that shares some components.

 Registry has one possible internal mutation - caching instances.
 That cache also copied to new registries wich created with register methods."
shared class ImmutableRegistry satisfies Registry {

    late MetaRegistry metaRegistry;

    late Map<[Class<>, String], Anything> parameters;

    late Map<Interface<>, [Class<>+]> enhancerComponents;

    late variable Map<Class<>, Anything> componentsCache;


    shared void inspect() {
        print("---------------- REGISTRY INSPECTION -----------------");
        printAll({
            "parameters size: ``parameters.size``",
            "componentsCache size: ``componentsCache.size``",
            "enhancerComponents size: ``enhancerComponents.size``"
        }, "\n");
        printSection("parameters", parameters);
        printSection("componentsCache", componentsCache);
        printSection("enhancerComponents", enhancerComponents);
        metaRegistry.inspect();
    }

    shared new (
            "Components - class declarations or instances, which will be instantiated
             and returned by getInstance method"
            {Component*} components = empty,
            "Direct parameters for custom classes.
             Shape: [class-for-injection, constructor-parameter-name, value-to-inject]"
            {ParameterForInjection*} parameters = empty,
            "Enhancers is simple wrapper classes, wich can be used as adhoc AOP."
            {EnchancersDeclaration*} enhancers = empty) {

        value classInstencePairs = components.collect(getClassInstancePair);
        this.componentsCache = map(classInstencePairs);
        this.metaRegistry = MetaRegistry(classInstencePairs*.key);

        this.parameters = map {
            for ([type, paramName, val] in parameters)
            [type, paramName]->val
        };

        if (nonempty errors = [*enhancers.map(unflatten(checkEnchancers<Anything>)).coalesced]) {
            throw errors.first;
        }
        this.enhancerComponents = map {
            for ([iface, wrappers] in enhancers)
            iface->wrappers
        };
    }

    "Internal constructor, need for self-copying"
    new withState(
            MetaRegistry metaRegistry,
            Map<[Class<>, String], Anything> parameters,
            Map<Interface<>, [Class<>+]> enhancerComponents,
            Map<Class<>, Anything> componentsCache) {
        this.metaRegistry = metaRegistry;
        this.parameters = parameters;
        this.enhancerComponents = enhancerComponents;
        this.componentsCache = componentsCache;
    }

    // pipe function
    [Class<T>, T|Exception] tryToCreateInstanceIfNotExists<T>([Class<T>, T?] instantiated) {
        value [clazz, instance] = instantiated;
        if (exists instance) {
            return [clazz, instance];
        }
        if (clazz in basicTypes) {
            value errorMsg = "Registry do not create basic types: " +
            "they should be specified as parameters or created instances basicTypes";
            return [clazz, Exception(errorMsg)];
        }
        return [clazz, tryToCreateInstance(clazz)];
    }

    T|Exception tryToCreateInstance<T>(Class<T> clazz) {
        try {
            log.debug(() => "tryToCreateInstance: class <``clazz``>");
            value paramsWithTypes = resolveConstructorParameters(clazz);
            log.trace(() => "tryToCreateInstance: default constructor for " +
            "type <``clazz``> has ``paramsWithTypes.size`` parameters");
            value params = instantiateParameters(clazz, paramsWithTypes);
            log.trace(() => "tryToCreateInstance: try to instantiate type <``clazz``> with params: <``params``>");
            value instance = clazz.namedApply(params);
            log.debug(() => "tryToCreateInstance: instantiated created for type <``clazz``>");
            return instance;
        } catch (Exception th) {
            value errorMsg = "Can't create instantiated: ``th.message``";
            log.error(() => "tryToCreateInstance: ``errorMsg``");
            return Exception(errorMsg);
        }
    }


    // pipe function
    T|Exception wrapClassWithEnchancer<T>(Type<T> requestedType)([Class<T>, T|Exception] instantiated) {
        value [clazz, instanceOrException] = instantiated;
        if (is T instance = instanceOrException) {
            log.debug(() => "wrapClassWithEnchancer: instance <``instance else "null"``> created for type <``clazz``>");
            value enhancers = enhancerComponents.getOrDefault(requestedType, empty);

            if (nonempty enhancers) {
                log.debug(() => "wrapClassWithEnchancer: has registered enhancers for type <``requestedType``>: ``enhancers``");
                return wrapWithEnhancer(requestedType, enhancers, instance, clazz);
            }
            log.debug(() => "wrapClassWithEnchancer: hasn't registered enhancers for type <``requestedType``>:");
        }
        return instanceOrException;
    }


    // pipe function
    T|Exception wrapClassWithEnchancer2<T>(Type<T> requestedType)([Class<T>, T] instantiated) {
        value [clazz, instance] = instantiated;
        log.debug(() => "wrapClassWithEnchancer: instance <``instance else "null"``> created for type <``clazz``>");
        value enhancers = enhancerComponents.getOrDefault(requestedType, empty);
        if (nonempty enhancers) {
            log.debug(() => "wrapClassWithEnchancer: has registered enhancers for type <``requestedType``>: ``enhancers``");
            return wrapWithEnhancer(requestedType, enhancers, instance, clazz);
        }
        log.debug(() => "wrapClassWithEnchancer: hasn't registered enhancers for type <``requestedType``>:");
        return instance;
    }

    T|Exception wrapWithEnhancer<T>(Type<T> requestedType,
            [Class<Anything, Nothing>+] enhancers,
            T instance,
            Class<T, Nothing> clazz) {
        variable T wrapped = instance;
        for (e in enhancers) {
            value params = resolveConstructorParameters(e);
            value [instanceParam, otherParams]
                    = divideByFilter(params, (Parameter p) => p.parameterType.typeOf(instance));
            value instantiatedOtherParams = instantiateParameters(e, otherParams);

            value fullParams = expand {
                instantiatedOtherParams,
                instanceParam.map(bindParameterWithValue(wrapped))
            };
            assert (is T newWrapped = e.namedApply(fullParams));
            log.trace(() => "wrapClassWithEnchancer: create wrapper <``e``> for type <``clazz``>");
            wrapped = newWrapped;
        }
        log.debug(() => "wrapClassWithEnchancer: instance of <``clazz``> successfully wrapped");
        return wrapped;
    }

    "Main high-level function"
    T? tryFindAndGetApproproateInstance<T>(Type<T> t) {
        log.debug(() => "tryFindAndGetApproproateInstance: for type <``t``> ");

        value appropriateClasses = expand {
            [if (is Class<T> t , !t.declaration.abstract) t],
            metaRegistry.getAppropriateClassForType(t)
        };

        value firstPotentiallyCreated =
                appropriateClasses
                    .map(getFromCache)
                    .map(tryToCreateInstanceIfNotExists)
                    .map(saveToCache)
                    .map(wrapClassWithEnchancer<Anything>(t))
                    .find(notException);

        if (is T i = firstPotentiallyCreated) {
            return i;
        }
        log.warn(() => "tryFindAndGetApproproateInstance: can't get instantiated: for type ``t``");
        return null;
    }


    [Class<T>, T?] getFromCache<T>(Class<T> clazz) {
        log.debug(() => "getFromCache: called with class <``clazz``>");
        if (exists instance = componentsCache[clazz]) {
            log.debug(() => "getFromCache: <``clazz``> has cached value");
            return [clazz, cast<T>(instance)];
        } else {
            log.debug(() => "getFromCache: <``clazz``> hasn't cached value");
            return [clazz, null];
        }
    }


    // pipe function
    [Class<T>, T|Exception] saveToCache<T>([Class<T>, T|Exception] instantiated) {
        log.debug(() => "saveToCache: called with params <``instantiated``>");
        value [clazz, instance] = instantiated;
        if (!is Exception instance,
            !componentsCache[clazz] exists) {
            log.debug(() => "saveToCache: there are no cached value for <``instantiated``>. cache it!");
            componentsCache = componentsCache.patch(map { clazz->instance });
        }
        return instantiated;
    }

//    - [[ClassOrInterface]]
//    - [[ClassOrInterface]]
//    - [[UnionType]]
//    - [[IntersectionType]]

    "Try to create instance for given type (class/interface/union/intersection)"
    throws (`class Exception`, "When can't create instance.")
    shared actual T getInstance<T>(Type<T> t) {
        log.info(() => "getInstance: for type <``t``>");
        if (exists i = tryFindAndGetApproproateInstance(t)) {
            return i;
        }
        throw Exception("Registry.getInstance: can't createInstance for class <``t``>");
    }

    [<String->Anything>*]
    instantiateParameters<T>(Class<T> t, {Parameter*} paramsTypes) {
        log.debug(() => "instantiateParameters: try to instantiate params: ``paramsTypes``");
        return paramsTypes
            .map(getRegisteredParameter)
            .map(instantiateParameterIfNotExists)
            .coalesced.sequence();
    }

    [Parameter, Anything] getRegisteredParameter(Parameter p) {
        if (exists paramVal = parameters[[p.targetClass, p.parameterName]]) {
            log.trace(() => "getRegisteredParameter: found registered parameter for : [``p.targetClass``,``p.parameterName``]");
            return [p, paramVal];
        }
        log.trace(() => "getRegisteredParameter: there are no registered parameter for : [``p.targetClass``,``p.parameterName``]");
        return [p, null];
    }

    // pipe function
    <String->Anything>? instantiateParameterIfNotExists([Parameter, Anything] parameterValuePair) {
        value [parameter, val] = parameterValuePair;
        if (exists val) {
            return parameter.parameterName->val;
        }
        return instantiateParameter(parameter);
    }

    <String->Anything>? instantiateParameter(Parameter p) {
        log.trace(() => "instantiateParameter: try to instantiate parameter <``p.parameterName``> needed for class <``p.targetClass``>");
        value depInstance = tryFindAndGetApproproateInstance(p.parameterType);
        if (exists depInstance) {
            log.trace(() => "instantiateParameter: parameter <``p.parameterName``> initialized");
            return p.parameterName->depInstance;
        }
        log.trace(() => "instantiateParameter: parameter <``p.parameterName``>(``p.targetClass``) NOT initialized.");
        if (p.defaulted) {
            log.trace(() => "instantiateParameter: parameter <``p.parameterName``>(``p.targetClass``) has default value in class.");
            return null;
        }
        throw Exception("Unresolved dependency <``p.parameterName``> " +
        "(``p.parameterType``) for class <``p.targetClass``>");
    }

    shared actual Registry patch(Registry registry) {
        if(is ImmutableRegistry registry) {
            return withState {
                parameters = parameters.patch(registry.parameters);
                metaRegistry = metaRegistry;
                componentsCache = componentsCache.patch(registry.componentsCache);
                enhancerComponents = enhancerComponents.patch(registry.enhancerComponents);
            };
        }
        return ChainedRegistry(this, registry);
    }
}

"Chained registry - pure composition registry. Takes 2 registries
 and chains method-calls in parameter order - 'first' -> 'second'"
class ChainedRegistry(Registry first, Registry second) satisfies Registry {
    shared actual T getInstance<T>(Type<T> t) {
        try {
            return first.getInstance(t);
        } catch(Exception e) {
            return second.getInstance(t);
        }
    }

    patch(Registry registry) => ChainedRegistry(this, registry);
}

shared Registry newRegistry(
        {Component*} components = empty,
        {ParameterForInjection*} parameters = empty,
        {EnchancersDeclaration*} enchancers = empty) => ImmutableRegistry {
    components = components;
    parameters = parameters;
    enhancers = enchancers;
};

shared Registry components(Component* components)
        => ImmutableRegistry { components = components; };

shared Registry parameters(ParameterForInjection* parameters)
        => ImmutableRegistry { parameters = parameters; };

shared Registry enchancers(EnchancersDeclaration* enchancers)
        => ImmutableRegistry { enhancers = enchancers; };

Exception? checkEnhancerInterfaceCompatibility<Target, Wrapper>(
        Type<Target>->[Set<Class<>>, Set<Interface<>>] targetInfo,
        Class<Wrapper>->[Set<Class<>>, Set<Interface<>>] wrapperInfo) {

    value targetClassOrIface->[targetExtendClasses, targetInterfaces] = targetInfo;
    value wrapperClass->[wrapperExtendClasses, wrapperInterfaces] = wrapperInfo;

    value targetInterfaceSet = set {
        if(is Interface<> iface = targetClassOrIface) iface
    }.union(targetInterfaces);
    
    value wrapperInterfaceSet = set(wrapperInterfaces);

    log.trace(() =>"checkEnhancerInterfaceCompatibility: check enhancer " +
    "``wrapperInfo.key`` compatibility with type <``targetInfo.key``>");

    // if target is subset of wrapper -> ok
    if(targetInterfaceSet.subset(wrapperInterfaceSet)) {
        log.trace(() =>"checkEnhancerInterfaceCompatibility: check passed");
        return null;
    }
    value missed = targetInterfaceSet.complement(wrapperInterfaceSet);

    log.trace(() =>"checkEnhancerInterfaceCompatibility: check failed, violations: ``missed``");

    return Exception("Enchancer class <``wrapperInfo.key``> not compatible " +
    "with origin class <``targetInfo.key``>: missed interfaces ``missed``");
}

"Checks if enhancer takes at least one parameter with the same interface that it wraps."
Exception? checkEnhancerConstructorCompatibility<Target, Wrapper>(
        Type<Target>->[Set<Class<>>, Set<Interface<>>] targetInfo,
        Class<Wrapper>->[Set<Class<>>, Set<Interface<>>] wrapperInfo) {
    value targetClass->[targetExtendClasses, targetInterfaces] = targetInfo;
    value wrapperClass->[wrapperExtendClasses, wrapperInterfaces] = wrapperInfo;

    log.trace(() =>"checkEnhancerConstructorCompatibility: check enhancer " +
    "``wrapperClass`` compatibility with type <``targetClass``>");

    value wrapperParams = resolveConstructorParameters(wrapperClass);

    value isThereTargetAsParameter = any {
        for (paramType in wrapperParams*.parameterType)
        paramType in expand {{targetClass}, targetExtendClasses, targetInterfaces}
    };
    if (isThereTargetAsParameter) {
        log.trace(() =>"checkEnhancerConstructorCompatibility: check passed");
        return null;
    }
    log.trace(() =>"checkEnhancerConstructorCompatibility: check failed");

    return Exception("Enhancer class <``wrapperClass``> must have at least " +
    "one constructor parameter with <``targetClass``> or some of it interfaces ``targetInterfaces``");
}

"Silly check-function composition, which don't agregate Exceptions. Returns first"
Exception? checkEnchancer<T, W>(Class<T>|Interface<T> target, Class<W> wrapper) {
    log.debug(() =>"checkEnchancer: check enhancer ``wrapper`` compatibility with type <``target``>");
    value targetInfo =
            if(is Class<T> target)
            then describeClass(target)
            else target->[emptySet, set(getInterfaceHierarchySet(target))];

    value wrapperInfo = describeClass(wrapper);

    return checkEnhancerInterfaceCompatibility(targetInfo, wrapperInfo)
    else checkEnhancerConstructorCompatibility(targetInfo, wrapperInfo);
}

"Another silly check-function composition that don't aggregate errors in nice way."
Exception? checkEnchancers<T>(Class<T>|Interface<T> target, [Class<>+] wrappers) {
    log.debug(() =>"checkEnchancers: check enhancers ``wrappers`` compatibility with type <``target``>");
    return checkEnchancer(target, wrappers.first)
    else wrappers.paired.map(unflatten(checkEnchancer<Anything, Anything>)).coalesced.first;
}

"split into 2 collections by a predicate"
[{Entity*}, {Entity*}] divideByFilter<Entity>(
        {Entity*} coll, Boolean pred(Entity p))
        => [ coll.filter(pred), coll.filter(not(pred)) ];

String->T bindParameterWithValue<T>(T val)(Parameter param)
        => param.parameterName->val;

T cast<T>(Anything val){
    assert(is T val);
    return val;
}

Boolean  notException(Anything instanceOrException)
        => !instanceOrException is Exception;

"Helper function for state inspection"
shared void printSection<T>(String sectionName, {T*} coll) {
    if(!coll.empty) {
        print("-------------------- ``sectionName`` ----------------------");
        printAll(coll, "\n");
    }
}
