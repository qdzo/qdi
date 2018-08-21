import ceylon.language.meta.model {
    Type,
    IntersectionType,
    UnionType,
    Interface,
    Class
}
import com.github.qdzo.qdi {
    printSection
}

"Class meta-information store.

 Gets classes and gather information from them:
 - full class hierarchy (except Basic types)
 - satisfied interfaces by that class hierarchy

 Can suggest classes which fit requirements by
 request (interfaces/intersection/union/abstract-types)

 Used as requirements(class) resolution engine."
shared class MetaRegistry {

    "Class -> ['extend classes', 'satisfied interfaces']"
    Map<Class<>, [Set<Class<>>, Set<Interface<>>]> components;

    "Dictionary of 'ParentClass -> ChildClass'."
    Map<Class<>, Set<Class<>>> extendComponents;

    "Inteface dictionary: 'Interface -> SatisfiedClass'."
    Map<Interface<>, Set<Class<>>> interfaceComponents;

    "Create new MetaRegistry from given classes"
    shared new({Class<Anything>*} components = empty) {

        value described = components.collect(describeClass);

        this.components = map(described);
        
        value parentChildEntries = {
            for (clazz-> [extClazzez, __] in described)
            for(extClazz in extClazzez)
            extClazz -> clazz
        };
        
        value extendComponents = parentChildEntries
            .group((parent->child) => parent)
            .map((parent->parentChildEntries) => parent -> set(parentChildEntries*.item));

        this.extendComponents = map(extendComponents);

        value interfaceClassEntries = {
            for (clazz->[ __, ifaces] in described)
            for (iface in ifaces)
            iface -> clazz
        };

        value interfaceComponents = interfaceClassEntries
            .group((iface->clazz) => iface)
            .map((iface->ifaceClass) => iface -> set(ifaceClass*.item));

        this.interfaceComponents = map(interfaceComponents);
    }

    "Internal constructor, need for self-copying"
    new withState (
            Map<Class<>, [Set<Class<>>, Set<Interface<>>]> components,
            Map<Class<>, Set<Class<>>> extendComponents,
            Map<Interface<>, Set<Class<>>> interfaceComponents
            ) {
        this.components = components;
        this.extendComponents = extendComponents;
        this.interfaceComponents = interfaceComponents;
    }

    shared MetaRegistry patch(MetaRegistry metaRegistry) {
        return withState {
            components = components.patch(metaRegistry.components); // rewrite clazz-info without risk.
            extendComponents = mergeMapsWith<Class<>, Set<Class<>>> {
                first = extendComponents;
                second = metaRegistry.extendComponents;
                mergeFn = (a,  b) => a.union(b);
            };
            interfaceComponents = mergeMapsWith<Interface<>, Set<Class<>>> {
                first = interfaceComponents;
                second = metaRegistry.interfaceComponents;
                mergeFn = (a,  b) => a.union(b);
            };
        };
    }

//        shared Boolean isRegistered<T>(Class<T> clazz) => componentsCache[clazz] exists;
    
    shared [Interface<>*] getClassInterfaces<T>(Class<T> clazz)
            => if(exists [_, ifaces] = components[clazz]) then ifaces.sequence() else [];

    shared [Class<>*] getClassHierarchy<T>(Class<T> clazz)
            => if(exists [classes,_] = components[clazz]) then classes.sequence() else [];

    shared [Set<Class<>>, Set<Interface<>>] getClassInfo<T>(Class<T> clazz)
            =>  components[clazz] else [emptySet, emptySet];

    shared [Class<>*] getAppropriateClassForType<T>(Type<T> t) {

        if (is Interface<T> t) {
            log.debug(() => "getAppropriateClassForType: <``t``> is a Interface");
            if(exists satisfiedClass = interfaceComponents.get(t)) {
                log.debug(() => "getAppropriateClassForType: has registered class <``satisfiedClass``> for interface <``t``>");
                return satisfiedClass.sequence();
            }
            log.warn(() => "getAppropriateClassForType: Haven't registered types for interface: <``t``>");
            return empty;
        }

        else if(is Class<T> t) {
            log.debug(() => "getAppropriateClassForType: <``t``> is a Class");
            if(exists extendedClass = extendComponents.get(t)) {
                log.debug(() => "getAppropriateClassForType: has registered type for class <``t``>");
                return extendedClass.sequence();
            }
            log.warn(() => "getAppropriateClassForType: Haven't registered types for class: <``t``>");
            return empty;
        }

        else if(is UnionType<T> t) {
            log.debug(() => "getAppropriateClassForType: <``t``> is an UnionType");
            return concatenate(t.caseTypes.narrow<Class<>>(), t.caseTypes.flatMap(getAppropriateClassForType));
        }

        else if(is IntersectionType<T> t) {
            log.debug(() => "getAppropriateClassForType: <``t``> is an IntersectionType");

            value intersectedTypesSet = set(t.satisfiedTypes);
            
            value intersected = interfaceComponents
                .filterKeys(intersectedTypesSet.contains)
                .flatMap((iface -> clazzez) => { for (clazz in clazzez) clazz -> iface })
                .group(Entry.key)
                .map((clazz -> clazzIfaces) => clazz -> clazzIfaces*.item)
                .select((clazz -> ifaces) => set(ifaces).superset(intersectedTypesSet));

            if(nonempty intersected) {
                return intersected*.key;
            }
            log.warn(() => "getAppropriateClassForType: Haven't registered types for interface intersection: <``t``>");
            return empty;
        }
        // not found
        log.warn(() => "getAppropriateClassForType: Type is not interface nor class: <``t``>");
        return empty;
    }

    shared MetaRegistry registerMetaInfoForType<T>(Class<T> t) {
        log.info("describeAndRegisterType: register type <``t``>");
        value clazz->[extClazzez, ifaces] = describeClass(t);

        return withState {
            components = components.patch(map {clazz -> [extClazzez, ifaces]}); // rewrite clazz-info without risk.
            extendComponents = extendComponents.patch( map {
                for (extClazz in extClazzez)
                if(exists clazzez = extendComponents[extClazz])
                then extClazz -> clazzez.union(set{clazz})
                else extClazz -> set{clazz}
            });
            interfaceComponents = interfaceComponents.patch( map {
                for (iface in ifaces)
                if(exists clazzez = interfaceComponents[iface])
                then iface -> clazzez.union(set{clazz})
                else iface -> set{clazz}
            });
        };
    }

    Map<T,V> mergeMapsWith<T,V>(Map<T,V> first, Map<T,V> second, V mergeFn(V a, V b)) given T satisfies Object
            => first.chain(second)
                  .summarize(Entry.key,
                      (V? valA, T keyB -> V valB)
                       => if (exists valA) then mergeFn(valA, valB) else valB);

    "Helper function for debugging"
    shared void inspect() {
        print("---------------- META-REGISTRY INSPECTION -----------------");
        printAll({
            "componentsCache size: ``components.size``",
            "interfaceComponents size: ``interfaceComponents.size``",
            "extendComponents size: ``extendComponents.size``"
        }, "\n");
        printSection("components", components);
        printSection("interfaceComponents", interfaceComponents);
        printSection("extendComponents", extendComponents);
        print("------------------------------------------------------------");
    }
}