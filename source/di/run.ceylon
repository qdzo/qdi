import ceylon.collection {
    MutableMap,
    HashMap
}
import ceylon.language {
    ceylonPrint=print
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
    debug,
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
    defaultPriority = trace;
}

// ----------------------------------------------------

class Registry {

//    class RegistryState(
//            shared Map<[Type<>, String],Anything> parameters = emptyMap,
//            shared Map<Type<>, Anything> components = emptyMap,
//            shared Map<Interface<>, Class<>> interfaceComponents = emptyMap)  {
//
//        shared RegistryState with(
//                Map<[Type<>, String], Anything> parameters = this.parameters,
//                Map<Type<>, Anything> components = this.components,
//                Map<Interface<>, Class<>> interfaceComponents = this.interfaceComponents
//                )  => RegistryState(parameters, components, interfaceComponents);
//
//    }


    MutableMap<[Class<>, String], Anything> parameters
            = HashMap<[Class<>, String], Anything> {};

    MutableMap<Class<>, Anything> components
            = HashMap<Class<>, Anything> {};

    MutableMap<Class<>, Class<>> extendComponents
            = HashMap<Class<>, Class<>> {};

    MutableMap<Interface<>, Class<>> interfaceComponents
            = HashMap<Interface<>, Class<>> {};

    shared void inspect() {
        print("---------------- REGISTRY INSPECTION -----------------");
        printAll({
            "interfaceComponents size: ``interfaceComponents.size``",
            "components size: ``components.size``",
            "parameters size: ``parameters.size``"
        }, "\n");
        if (!interfaceComponents.empty) {
            print("--------------- interfacesComponenets ----------------");
            printAll(interfaceComponents, "\n");
        }
        if (!components.empty) {
            print("-------------------- components ----------------------");
            printAll(components, "\n");
        }
        if (!parameters.empty) {
            print("-------------------- parameters ----------------------");
            printAll(parameters, "\n");
        }
        print("------------------------------------------------------");
    }

    shared new(
            {Class<>|Object*} components = empty,
            {[Class<>, String, Anything]*} parameters = empty) {

        value described = components.collect(describeComponent);
        this.components.putAll {
            for ([inst, clazz, *_] in described)
            clazz -> inst
        };
        this.extendComponents.putAll {
            for ([_, clazz, extClazz, __] in described)
            extClazz -> clazz
        };
        this.interfaceComponents.putAll {
            for ([_, clazz, __, ifaces] in described)
            for (iface in ifaces)
            iface -> clazz
        };
        this.parameters.putAll {
            for ([type, paramName, val] in parameters)
            [type, paramName] -> val
        };
    }


    class Parameter(
            shared String name,
            shared Type<> type,
//            shared OpenType type,
            shared Boolean defaulted
            )  {
        string => "Parameter(name=``name``, type=``type``, defaulted=``defaulted``)";
    }

    shared void registerParameter<T>(Class<T> t, String param, Anything val) {
        log.info("Registry.registerParameter: for type <``t``>, name: <``param``>, val: <``val else "null"``>");
        parameters.put([t, param], val);
    }

    shared void register<T>(Class<T>|Object typeOrInstance) {
        value [inst, clazz, extClazz, ifaces] = describeComponent(typeOrInstance);
        components.put(clazz, inst);
        extendComponents.put(extClazz, clazz);
        log.info("Registry.register: register " +
                    (if(exists inst) then "instance: <``inst``> for " else "") +
                "type <``clazz``>");
        interfaceComponents.putAll { for (iface in ifaces) iface -> clazz };
    }

    T tryToCreateInstance<T>(Class<T> t) {
        try {
            log.debug(() => "Registry.tryToCreateInstance: class <``t``>");
            value paramsWithTypes = constructParameters(t);
            if (paramsWithTypes.empty) {
                log.trace(() => "Registry.tryToCreateInstance: default constructor for type <``t``> is without parameters");
                value instance = t.apply();
                log.info("Registry.tryToCreateInstance: instance created for type <``t``>");
                return instance;
            }
            log.trace(() => "Registry.tryToCreateInstance: default constructor for "+
                      "type <``t``> has ``paramsWithTypes.size`` parameters");
            value params = instantiateParams(t, paramsWithTypes);
            log.trace(() => "Registry.tryToCreateInstance: try to instantiate type <``t``> with params: <``params``>");
            value instance = t.namedApply(params);
            log.debug(() => "Registry.tryToCreateInstance: instance created for type <``t``>");
            return instance;
        } catch(Exception th) {
            value errorMsg = "Can't create instance: ``th.message``";
            log.error(() => "Registry.tryToCreateInstance: ``errorMsg``");
            throw Exception(errorMsg);
        }
    }

    T instantiateClass<T>(Class<T> t) {
        // registered class
        if (components.defines(t)) {
            log.debug(() => "Registry.getInstance: components has registered type <``t``>");
            if (exists instance = components.get(t)) {
                log.debug(() => "Registry.getInstance: components has instance for type <``t``>");
                assert (is T instance);
                return instance;
            } else {
                log.debug(() => "Registry.getInstance: components has not instance for type <``t``>");
                value instance = tryToCreateInstance(t);
                components.put(t, instance);
                return instance;
            }
        }
       // abstract class
        else if (exists tt = extendComponents[t]) {
            value instance = instantiateClass(tt);
            assert (is T instance);
            return instance;
        }
        log.error(() => "Registry.getInstance: components has not registered type ``t``");
        throw Exception("There are no such type in Registry <``t``>");
    }

    T? tryGetInstance<T>(Type<T> t) {
       try {
            return getInstance(t);
       } catch (Exception e) {
           log.warn(() => "Registry.tryGetInstance: can't get instance: ``e.message``");
           return null;
       }
    }

//    - [[ClassOrInterface]]
//    - [[ClassOrInterface]]
//    - [[UnionType]]
//    - [[IntersectionType]]

    shared T getInstance<T>(Type<T> t) {
        log.info(() => "Registry.getInstance: for type <``t``>");
        // interface
        if (is Interface<T> t) {
            if(is Class<T> satisfiedClass = interfaceComponents.get(t)) {
                log.debug(() => "Registry.getInstance: has registered type for interface <``t``>");
                return instantiateClass(satisfiedClass);
            }
        }
        // class
        else if(is Class<T> t) {
            return instantiateClass(t);
        }
        // union
        else if(is UnionType<T> t) {
            assert(is T i = t.caseTypes.map(tryGetInstance).coalesced.first);
            return i;
        }
        // intersection
        else if(is IntersectionType<T> t) {

            value intersected = interfaceComponents
                .filterKeys((iface) => iface in t.satisfiedTypes)
                .inverse()
                .find((clazz -> ifaces) => ifaces.every((iface) => iface in t.satisfiedTypes));
            
            if(exists intersected,
                is Class<T> cl = intersected.key) {
                return instantiateClass(cl);
            }
        }
        // not found
        value msg = "Type is not interface nor class: <``t``>";
        log.error(() => "Registry.getInstance: ``msg``");
        throw Exception(msg);
    }

    Type<> closeOpenType<T>(Class<T> t, OpenType openType) => switch(ot = openType)
    case (is OpenClassType) ot.declaration.classApply<Anything>(*t.typeArgumentList)
    case (is OpenInterfaceType) ot.declaration.interfaceApply<Anything>(*t.typeArgumentList)
    case (is OpenUnion) closeOpenUnionType(t, ot)
    case (is OpenIntersection) closeOpenIntersectionType(t, ot)
    case (is OpenTypeVariable) closeOpenTypeVariable(t, ot)
    case (nothingType) nothing;

    // REVIEW: Analyze this part better (Vitaly 25.06.2018)
    Type<> closeOpenTypeVariable<T>(Class<T> t, OpenTypeVariable ot) {
        value decl = ot.declaration;
//        log.debug("----------------------------------------------");
//        log.debug(() => "decl " + decl.string);
//        log.debug(() => "caseType " + decl.caseTypes.string);
//        log.debug(() => "container " + decl.container.string);
//        log.debug(() => "dafTypeArg " + (decl.defaultTypeArgument?.string else ""));
//        log.debug(() => "satisfiedTypes " + decl.satisfiedTypes.string );
//        log.debug(() => "variance " + decl.variance.string);
//        log.debug(() => "AAAA" + t.typeArguments.string);
//        log.debug("----------------------------------------------");
        if(exists typeVar = t.typeArguments[ot.declaration]) {
            return typeVar;
        }
//        if (nonempty ct = ot.declaration.caseTypes) {
//            return closeOpenType(t, ct.first);
//        }
//        else if(exists dta = ot.declaration.defaultTypeArgument) {
//            return closeOpenType(t, dta);
//        }
//        else if (nonempty st = ot.declaration.satisfiedTypes) {
//            return closeOpenType(t, st.first);
//        }
        throw Exception("I Don't know what to do in this situation (OpenTypeVariable)");
    }

    Type<> closeOpenUnionType<T>(Class<T> tt, OpenUnion ot) {
        value types = ot.caseTypes.map((t) => closeOpenType(tt, t)).sequence();
        assert(nonempty types);
        return types.reduce<Type<>>((p, e) => p.union(e));
    }

    Type<> closeOpenIntersectionType<T>(Class<T> tt, OpenIntersection ot) {
        value types = ot.satisfiedTypes.map((t) => closeOpenType(tt, t)).sequence();
        assert(nonempty types);
        return types.reduce<Type<>>((p, e) => p.intersection(e));
    }

    {<String->Anything>*}
    instantiateParams<T>(Class<T> t, {Parameter*} paramsTypes) {
        log.debug(() => "Registry.instantiateParams: try to instantiate params: ``paramsTypes``");
        value instantiatedParams = paramsTypes.map (
                    (Parameter parameter) {
                if(exists paramVal = parameters[[t, parameter.name]]) {
                    return parameter.name -> paramVal;
                } else {
//                parameter.type
                    value typeArgs = t.typeArgumentList;
//                    value closeType = closeOpenType(parameter.type, *typeArgs);
                    value closeType = parameter.type;
                    value depInstance = tryGetInstance(closeType);
                    if(exists depInstance) {
                        return parameter.name -> depInstance;
                    }
                    if(parameter.defaulted) {
                        return null;
                    }
                    throw Exception("Unresolved dependency <``parameter.name``> (``parameter.type``) for class <``t``>");
                }
            }
        ).coalesced;
        return instantiatedParams;
    }

    {Parameter*} constructParameters<T>(Class<T> t) {
        log.debug(() => "Registry.constructParameters: parameters for class <``t``>");
        
        assert(exists parameterDeclarations
                = t.defaultConstructor?.declaration?.parameterDeclarations);
        value parameters =  parameterDeclarations.collect((e) {
            log.trace(() => "Registry.constructParameters: parameter-declaration: <``e.openType``>");
            value closedType = closeOpenType(t, e.openType);
            return Parameter(e.name, closedType, e.defaulted);
        });
        log.debug(() => "Registry.constructParameters: constructed parameters: <``parameters``>");
        return parameters;
    }
}

// TODO move to reflectionTools.ceylon file
[Class<T>, Class<Anything>, [Interface<Anything>*]]
describeClass<T>(Class<T> clazz) {
    
    // Only for Anything class extended class = null;
    assert(exists extendedClass =
            clazz.declaration.extendedType
                ?.declaration?.classApply<Anything>());

    value interfaces =
            if(nonempty interfaces = clazz.satisfiedTypes)
            then interfaces.collect((iface)
                => iface.declaration.interfaceApply<Anything>(*iface.typeArgumentList))
            else [];

    return [clazz, extendedClass, interfaces];
}

// TODO move to reflectionTools.ceylon file
[T, Class<T>, Class<Anything>, [Interface<Anything>*]]
describeInstance<T>(T instance) {
    assert(is Class<T> clazz = type(instance));
    return [instance, *describeClass(clazz)];
}

[Anything, Class<>, Class<>, [Interface<>*]]
describeComponent<T>(Class<T>|T comp) => switch(comp)
    case(is Class<T>) [null, *describeClass(comp)]
    else  describeInstance(comp);

// ========================= DESCRIBE-FUNCTIONS TESTS ==========================

test
shared void describeClass_SouldReturnCorrectInfo_ForClassWithMultiInterfaces() {
    value actual = describeClass(`RuPostman`);
    assertEquals(actual, [`RuPostman`, `Basic`, [`Postman`, `Operator`]]);
}


test
shared void describeInstance_SouldReturnCorrectInfo_ForClassWithMultiInterfaces() {
    value postman = RuPostman();
    value actual = describeInstance(postman);
    assertEquals {
        actual = actual;
        expected = [postman, `RuPostman`, `Basic`, [`Postman`, `Operator`]];
    };
}

//
//shared void run() {
//    value registry = Registry();
//    registry.register(`Atom`);
////    registry.registerParameter("name", "Vika");
////    registry.registerParameter("age", 18);
//    registry.register(`Atom`);
//    Atom atom = registry.getInstance(`Atom`);
//    print(atom);
//    Atom atom2 = registry.getInstance(`Atom`);
//    print(atom2);
////    value params = constructParameters(`Person`);
////    value params = constructParameters(`Person`);
////    print(params);
////    print(`Person`.defaultConstructor?.namedApply({"name"-> "Vitaly", "age"-> 31}));
//}

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
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCalled() {
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
    assertThatException(() => registry.getInstance(`Person`));
}

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

// ============================ CASE CLASS ================================

abstract class Fruit() of orange | apple { }
object apple extends Fruit() {}
object orange extends Fruit() {}

test
shared void describeInstance_SouldReturnCorrectInfo_ForCaseClass() {
    value actual = describeInstance(orange);
    assertEquals {
        actual = actual;
        // orange is class orange with signleton object
        expected = [orange, type(orange), `Fruit`, []];
    };
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

tag("repl")
test
shared void registryShouldCreateInstanceWithGenericTypeDependency() {
    value registry = Registry { `GenericTrackCar<String>`, `GenericBox<String>`, "String item" };
    value actual = registry.getInstance(`GenericTrackCar<String>`);
    assertIs(actual, `GenericTrackCar<String>`);
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
class Dog() extends Animal() { }
class Cat() extends Animal() { }


tag("abstract")
test
shared void registryShouldCreateInstanceForAbstractClass() {
    value registry = Registry {`Dog`};
    value animal = registry.getInstance(`Animal`);
    assertIs(animal, `Dog`);
}

