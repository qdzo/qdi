import ceylon.language.meta.model {
    Type,
    IntersectionType,
    UnionType,
    Interface,
    Class
}

shared class MetaRegistry {

    Map<Class<>, [[Class<>*], [Interface<>*]]> components;

    Map<Class<>, Class<>> extendComponents;

    Map<Interface<>, Class<>> interfaceComponents;

    shared new({Class<Anything>*} components = empty) {

        value described = components.collect(describeClass);

        this.components = map (described);

        this.extendComponents = map {
            for (clazz-> [extClazzez, __] in described)
            for(extClazz in extClazzez)
            extClazz -> clazz
        };

        this.interfaceComponents = map {
            for (clazz->[ __, ifaces] in described)
            for (iface in ifaces)
            iface -> clazz
        };
    }

    new withState (
            Map<Class<>, [[Class<>*], [Interface<>*]]> components,
            Map<Class<>, Class<>> extendComponents,
            Map<Interface<>, Class<>> interfaceComponents
            ) {
        this.components = components;
        this.extendComponents = extendComponents;
        this.interfaceComponents = interfaceComponents;
    }

//        shared Boolean isRegistered<T>(Class<T> clazz) => componentsCache[clazz] exists;
    
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

    shared MetaRegistry registerMetaInfoForType<T>(Class<T> t) {
        log.info("MetaRegistry.describeAndRegisterType: register type <``t``>");
        value clazz->[extClazzez, ifaces] = describeClass(t);
        return withState {
            components = components.patch(map {clazz -> [extClazzez, ifaces]});
            extendComponents = extendComponents.patch(map {
                for (extClazz in extClazzez) extClazz -> clazz
            });
            interfaceComponents = interfaceComponents.patch(map {
                for (iface in ifaces) iface -> clazz
            });
        };
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