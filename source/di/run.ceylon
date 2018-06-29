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

    MutableMap<Class<>|Interface<>, Class<>> enchancerComponents
            = HashMap<Class<>|Interface<>, Class<>> {};


    // TODO: Implement registerEnchancer (Vitaly 29.06.2018)
    shared void registerEnchnanser<T>(Class<T>|Interface<T> wrapped, [Class<>] wrappers) {

    }

    shared void inspect() {
        print("---------------- REGISTRY INSPECTION -----------------");
        printAll({
            "interfaceComponents size: ``interfaceComponents.size``",
            "components size: ``components.size``",
            "extendComponents size: ``extendComponents.size``",
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
        if (!extendComponents.empty) {
            print("-------------------- extendComponents ----------------------");
            printAll(extendComponents, "\n");
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

        // TODO: Add filter to ceylon-base-classes (Vitaly 29.06.2018)
        value described = components.collect(describeComponent);
        this.components.putAll {
            for ([inst, clazz, *_] in described)
            clazz -> inst
        };

        this.extendComponents.putAll {
            for ([_, clazz, extClazzez, __] in described)
            for(extClazz in extClazzez)
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
        value [inst, clazz, extClazzez, ifaces] = describeComponent(typeOrInstance);
        components.put(clazz, inst);
        extendComponents.putAll { for (extClazz in extClazzez) extClazz -> clazz };
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
            log.debug(() => "Registry.instantiateClass: components has registered type <``t``>");
            if (exists instance = components.get(t)) {
                log.debug(() => "Registry.instantiateClass: components has instance for type <``t``>");
                assert (is T instance);
                return instance;
            } else {
                log.debug(() => "Registry.instantiateClass: components has not instance for type <``t``>");
                value instance = tryToCreateInstance(t);
                components.put(t, instance);
                return instance;
            }
        }
       // abstract class
        else if (exists tt = extendComponents[t]) {
            log.debug(() => "Registry.instantiateClass: extendsComponents has registered type <``tt``> which extends type ``t``");
            value instance = instantiateClass(tt);
            assert (is T instance);
            return instance;
        }
        log.error(() => "Registry.instantiateClass: components has not registered type ``t``");
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
            log.debug(() => "Registry.getInstance: <``t``> is a Interface");
            if(is Class<T> satisfiedClass = interfaceComponents.get(t)) {
                log.debug(() => "Registry.getInstance: has registered type for interface <``t``>");
                return instantiateClass(satisfiedClass);
            }
            value msg = "Haven't registered types for interface: <``t``>";
            log.error(() => "Registry.getInstance: ``msg``");
            throw Exception(msg);
        }
        // class
        else if(is Class<T> t) {
            log.debug(() => "Registry.getInstance: <``t``> is a Class");
            return instantiateClass(t);
        }
        // union
        else if(is UnionType<T> t) {
            log.debug(() => "Registry.getInstance: <``t``> is an UnionType");
            assert(is T i = t.caseTypes.map(tryGetInstance).coalesced.first);
            return i;
        }
        // intersection
        else if(is IntersectionType<T> t) {
            log.debug(() => "Registry.getInstance: <``t``> is an IntersectionType");

            value intersected = interfaceComponents
                .filterKeys((iface) => iface in t.satisfiedTypes)
                .inverse()
                .find((clazz -> ifaces) => ifaces.every((iface) => iface in t.satisfiedTypes));
            
            if(exists intersected,
                is Class<T> cl = intersected.key) {
                return instantiateClass(cl);
            }
            value msg = "Haven't registered types for interface intersection: <``t``>";
            log.error(() => "Registry.getInstance: ``msg``");
            throw Exception(msg);
        }
        // not found
        value msg = "Type is not interface nor class: <``t``>";
        log.error(() => "Registry.getInstance: ``msg``");
        throw Exception(msg);
    }

    {<String->Anything>*}
    instantiateParams<T>(Class<T> t, {Parameter*} paramsTypes) {
        log.debug(() => "Registry.instantiateParams: try to instantiate params: ``paramsTypes``");
        value instantiatedParams = paramsTypes.map (
                    (Parameter parameter) {
                if(exists paramVal = parameters[[t, parameter.name]]) {
                    return parameter.name -> paramVal;
                } else {
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
            value closedType = resolveOpenType(t, e.openType);
            return Parameter(e.name, closedType, e.defaulted);
        });
        log.debug(() => "Registry.constructParameters: constructed parameters: <``parameters``>");
        return parameters;
    }
}


"Gets container class and open type, which need to relolve"
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
[Class<T>, [Class<Anything>*], [Interface<Anything>*]]
describeClass<T>(Class<T> clazz) {
    
    value extendedClazzez = describeClassHierarchyExceptBasicClasses(clazz);
    assert(is Interface<>[] interfaces =  clazz.satisfiedTypes);
    return [clazz, extendedClazzez, interfaces];
}

/*
  describe full-hierarchy from first extended class to Basic class (exclusive)
  <ceylon.language::Basic>
  <ceylon.language::Object>
  <ceylon.language::Anything>
*/

[Class<Anything>*]
describeClassHierarchyExceptBasicClasses<T>(Class<T> clazz) {

    // Only for Anything class extended-class = null;
    assert(exists extendedClassOpenType = clazz.declaration.extendedType);
    assert(is Class<> extendedClass = resolveOpenType(clazz, extendedClassOpenType));
    log.trace(() => "describeClassHierarchyExceptBasicClass:  ``extendedClass``");
    if(extendedClass.exactly(`Basic`)
       || extendedClass.exactly(`Object`)
       || extendedClass.exactly(`Anything`)) {
        log.trace(() => "describeClassHierarchyExceptBasicClass: reached Basic class");
        return empty;
    }
    return [extendedClass, *describeClassHierarchyExceptBasicClasses(extendedClass)];
}

// TODO move to reflectionTools.ceylon file
[T, Class<T>, [Class<Anything>*], [Interface<Anything>*]]
describeInstance<T>(T instance) {
    assert(is Class<T> clazz = type(instance));
    return [instance, *describeClass(clazz)];
}

[Anything, Class<>, [Class<>*], [Interface<>*]]
describeComponent<T>(Class<T>|T comp) => switch(comp)
    case(is Class<T>) [null, *describeClass(comp)]
    else  describeInstance(comp);

// ========================= DESCRIBE-FUNCTIONS TESTS ==========================

test
shared void describeClass_SouldReturnCorrectInfo_ForClassWithMultiInterfaces() {
    value actual = describeClass(`RuPostman`);
    assertEquals(actual, [`RuPostman`, [], [`Postman`, `Operator`]]);
}


test
shared void describeInstance_SouldReturnCorrectInfo_ForClassWithMultiInterfaces() {
    value postman = RuPostman();
    value actual = describeInstance(postman);
    assertEquals {
        actual = actual;
        expected = [postman, `RuPostman`, [], [`Postman`, `Operator`]];
    };
}

class One() { }
class OneOne() extends One() { }
class OneOneOne() extends OneOne() { }

test
shared void describeClassHierarhy_SouldReturnCorrectInfo_ForClassWithSeveralLevelInheritance() {
    value actual = describeClassHierarchyExceptBasicClasses(`OneOneOne`);
    assertEquals(actual, [`OneOne`, `One`]);
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
        expected = [orange, type(orange), [`Fruit`], []];
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

tag("repl")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependencyAndExtendedClasses2() {
    value registry = Registry {
        `GenericTanker<String, Integer>`,
        `StringBox2`,
        `IntegerBox`,
        "String item",
        101
    };
    registry.inspect();
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
//test
//shared void registryShouldCreateInstanceWithInvariantDependency() {
//    value registry = Registry {
//        `Bicycler<CrossBike>`,
//        `CrossBike`
//    };
//    value actual = registry.getInstance(`Bicycler<CrossBike>`);
//    assertIs(actual, `Bicycler<CrossBike>`);
//}

//tag("repl")
//test
//shared void registryShouldCreateInstanceWithContrvariantDependency() {
//    value registry = Registry {
//        `Bicycler<CrossBike>`,
//        `Bike`
//    };
//    value actual = registry.getInstance(`Bicycler<CrossBike>`);
//    assertIs(actual, `Bicycler<CrossBike>`);
//}

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

