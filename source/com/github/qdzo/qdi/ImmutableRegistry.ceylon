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
    getInterfaceHierarhy,
    MetaRegistry,
    resolveConstructorParameters,
    getClassInstancePair,
    basicTypes,
    Parameter
}


Logger log = logger(`module`);

// ----------------------------------------------------


"Immutable Registry - is container that stores information
 about classes, enhancers, parameters and can instantiate them later.

 Every register-method call returns new Registry with additional components/enhancers.
 Old Registry stays the same.

 > This way give you flexibility of creating separated registries that shares some components.

 Registry has one possible internal mutation - caching instances.
 That cache also copied to new registries wich created with register methods.
 "
shared class ImmutableRegistry satisfies Registry  {

    late MetaRegistry metaRegistry;

    late Map<[Class<>, String], Anything> parameters;

    late Map<Interface<>, [Class<>+]> enhancerComponents;

    late variable Map<Class<>, Anything> componentsCache;

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

    "Checks if enhancer takes at least one parameter with the same interface that it wraps."
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

    "Silly check-function composition, which don't agregate Exceptions. Returns first"
    Exception? checkEnchancer<T, W>(Class<T>|Interface<T> target, Class<W> wrapper) {
        log.debug(() =>"Registry.checkEnchancer: check enhancer ``wrapper`` compatibility with type <``target``>");
        value targetInfo =
                if(is Class<T> target)
                then describeClass(target)
                else target->[[], getInterfaceHierarhy(target)];
        
        value wrapperInfo = describeClass(wrapper);

        return checkEnhancerInterfaceCompatibility(targetInfo, wrapperInfo)
               else checkEnhancerConstructorCompatibility(targetInfo, wrapperInfo);
    }

    "Another silly check-function composition that don't aggregate errors in nice way."
    Exception? checkEnchancers<T>(Class<T>|Interface<T> target, [Class<>+] wrappers) {
        log.debug(() =>"Registry.checkEnchancers: check enhancers ``wrappers`` compatibility with type <``target``>");
        return checkEnchancer(target, wrappers.first)
               else wrappers.paired.map(unflatten(checkEnchancer<Anything, Anything>)).coalesced.first;
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
            "Components - class declarations or instances, which will be instantiated
             and returned by getInstance method"
            {Class<>|Object*} components = empty,
            "Direct parameters for custom classes.
             Shape: [class-for-injection, constructor-parameter-name, value-to-inject]"
            {[Class<>, String, Anything]*} parameters = empty,
            "Enhancers is simple wrapper classes, wich can be used as adhoc AOP."
            {[Interface<>, [Class<>+]]*} enhancers = empty) {

        value classInstencePairs = components.collect(getClassInstancePair);
        this.componentsCache = map(classInstencePairs);
        this.metaRegistry = MetaRegistry(classInstencePairs*.key);
        this.parameters = map {
            for ([type, paramName, val] in parameters)
            [type, paramName] -> val
        };

        if(nonempty errors = [*enhancers.map(unflatten(checkEnchancers<Anything>)).coalesced]){
            throw errors.first;
        }
        this.enhancerComponents = map {
            for([iface, wrappers] in enhancers)
            if(is Null checkError = checkEnchancers(iface, wrappers))
            iface -> wrappers
        };
    }

    "Internal constructor, need for sefl-copying"
    new withState(
            MetaRegistry metaRegistry,
            Map<[Class<>, String], Anything> parameters,
            Map<Interface<>, [Class<>+]> enhancerComponents,
            Map<Class<>, Anything> componentsCache
            ) {
        this.metaRegistry = metaRegistry;
        this.parameters = parameters;
        this.enhancerComponents = enhancerComponents;
        this.componentsCache = componentsCache;
    }



    shared actual Registry registerParameter<T>(Class<T> t, String param, Anything val) {
        log.info("Registry.registerParameter: for type <``t``>, name: <``param``>, val: <``val else "null"``>");
        return withState {
            metaRegistry = metaRegistry;
            parameters = parameters.patch(map{[t, param]-> val});
            enhancerComponents = enhancerComponents;
            componentsCache = componentsCache;
        };
    }

    shared actual Registry register<T>(Class<T>|Object typeOrInstance) {
        value clazz->inst = getClassInstancePair(typeOrInstance);
        log.info("Registry.register: register " +
                    (if(exists inst) then "instantiated: <``inst``> for " else "") +
                "type <``clazz``>");
        return withState {
            metaRegistry = metaRegistry.registerMetaInfoForType(clazz);
            parameters = parameters;
            enhancerComponents = enhancerComponents;
            componentsCache = componentsCache.patch(map{clazz -> inst});
        };
    }

    [Class<T>, T|Exception] tryToCreateInstanceIfNotExists<T>([Class<T>, T?] instantiated) {
        value [clazz, instance] = instantiated;
        if(exists instance) {
            return [clazz, instance];
        }
        if(clazz in basicTypes) {
            value errorMsg = "Registry do not create basic types: " +
                        "they should be specified as parameters or created instances basicTypes";
            return [clazz, Exception(errorMsg)];
        }
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


     T|Exception wrapClassWithEnchancer<T>(Type<T> requestedType)([Class<T>, T|Exception] instantiated)  {
        value [clazz, instanceOrException] = instantiated;
        if(is T instance = instanceOrException) {
            log.debug(() => "Registry.wrapClassWithEnchancer: instance <``instance else "null"``> created for type <``clazz``>");
            value enhancers = enhancerComponents.getOrDefault(requestedType, empty);
            if(nonempty enhancers) {
                log.debug(() => "Registry.wrapClassWithEnchancer: has registered enhancers for type <``requestedType``>: ``enhancers``");
                variable T wrapped = instance;
                for (e in enhancers) {
                    value params = resolveConstructorParameters(e);
                    value [instanceParam, otherParams] = divideByFilter(params, (Parameter p) => p.type.typeOf(instance));
                    value instantiatedOtherParams = instantiateParameters(e, otherParams);

                    value fullParams = expand {
                        instantiatedOtherParams,
                        instanceParam.map(bindParameterWithValue(wrapped))
                    };
                    assert(is T newWrapped = e.namedApply(fullParams));
                    log.trace(() => "Registry.wrapClassWithEnchancer: create wrapper <``e``> for type <``clazz``>");
                    wrapped = newWrapped;
                }
                log.debug(() => "Registry.wrapClassWithEnchancer: instance of <``clazz``> successfully wrapped");
                return  wrapped;
            }
            log.debug(() => "Registry.wrapClassWithEnchancer: hasn't registered enhancers for type <``requestedType``>:");
        }
        return instanceOrException;
    }

    [{Entity*}, {Entity*}] divideByFilter<Entity>(
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

        print("ITS- ``t``**************************************");
        value firstPotentiallyCreated =
                appropriateClasses
                    .map(getFromCache)
                    .map(tryToCreateInstanceIfNotExists)
                    .map(saveToCache)
                    .map(wrapClassWithEnchancer<Anything>(t))
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
            componentsCache = componentsCache.patch(map {clazz -> instance});
        }
        return instantiated;
    }

//    - [[ClassOrInterface]]
//    - [[ClassOrInterface]]
//    - [[UnionType]]
//    - [[IntersectionType]]

    shared actual T getInstance<T>(Type<T> t) {
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

    shared actual Registry registerEnhancer<T>(Interface<T> target, [Class<Anything,Nothing>+] wrappers) {
        log.info("Registry.registerEnchancer: try register enhancers ``wrappers`` for type <``target``>");
        if(is Exception error = checkEnchancers(target, wrappers)) {
            throw error;
        }
        log.info("Registry.registerEnchancer: register enhancers ``wrappers`` successfully");
        return withState {
            metaRegistry = metaRegistry;
            parameters = parameters;
            enhancerComponents = enhancerComponents.patch(map{target -> wrappers});
            componentsCache = componentsCache;
        };
    }
}

shared Registry newRegistry(
        {Class<>|Object*} components = empty,
        {[Class<>, String, Anything]*} parameters = empty,
        {[Interface<>, [Class<>+]]*} enhancers = empty
        ) => ImmutableRegistry {
    components = components;
    parameters = parameters;
    enhancers = enhancers;
};