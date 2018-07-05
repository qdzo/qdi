import ceylon.collection {
    MutableMap,
    HashMap
}
import ceylon.language.meta.model {
    Type,
    IntersectionType,
    UnionType,
    Interface,
    Class
}

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