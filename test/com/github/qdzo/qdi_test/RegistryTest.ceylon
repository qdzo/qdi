import ceylon.language.meta.model {
    Class,
    Interface,
    Type
}
import ceylon.logging {
    addLogWriter,
    writeSimpleLog,
    defaultPriority,
    error
}
import ceylon.test {
    beforeTestRun,
    test,
    assertEquals,
    assertIs,
    assertThatException,
    tag,
    parameters
}

import com.github.qdzo.qdi {
    newRegistry
}
import com.github.qdzo.qdi.meta {
    describeClass,
    getClassHierarchyExceptBasicClasses,
    getInterfaceHierarchySet,
    Parameter,
    getDependencySortedList
}
beforeTestRun
shared void setupLogger() {
    addLogWriter(writeSimpleLog);
    defaultPriority =
//             trace
//            info
        error
    ;
}


// ========================= DESCRIBE-FUNCTIONS TESTS ==========================

shared {[Class<>, [Set<Class<>>, Set<Interface<>>]]*} clazzAndInfo => [
   [`RuPostman`, [emptySet, set{ `Postman`, `Operator` }]],
   [`RuPostman2`, [set{`RuPostman`}, set{ `Postman`, `Operator` }]],
   [`RuPostman3`, [set{`RuPostman2`, `RuPostman`}, set{ `Postman`, `Operator` }]]
];

test parameters(`value clazzAndInfo`)
shared void describeClassPropertyTest(Class<Anything> clazz, [Set<Class<>>, Set<Interface<>>] clazzInfo)
        => assertEquals(describeClass(clazz), clazz -> clazzInfo);

class One() { }
class OneOne() extends One() { }
class OneOneOne() extends OneOne() { }

shared {[Class<Anything>, Set<Class<Anything>>]*} clazzHierarchy => [
    [`One`, emptySet],
    [`OneOne`, set{`One`}],
    [`OneOneOne`, set{`OneOne`, `One`}]

];

test parameters(`value clazzHierarchy`)
shared void describeClassHierarhyPropertyTest(Class<Anything> clazz, Set<Class<Anything>> hierarchy)
        => assertEquals(getClassHierarchyExceptBasicClasses(clazz), hierarchy);

interface A {}
interface B {}
interface C {}
interface AB satisfies A & B {}
interface ABC satisfies AB & C {}
class ClazzA() satisfies A {}
class ClazzB() satisfies B {}
class ClazzC() satisfies C {}
class ClazzAB() satisfies AB {}
class ClazzABC() satisfies ABC {}
class ClazzABC2() extends ClazzABC(){}

shared {[Class<Anything>, Set<Interface<Anything>>]*} clazzInterfaces => [
    [`ClazzA`, set{`A`}],
    [`ClazzB`, set{`B`}],
    [`ClazzC`, set{`C`}],
    [`ClazzAB`, set{`AB`, `A`, `B`}],
    [`ClazzABC`, set{`ABC`, `AB`, `A`, `B`, `C`}]
];

test parameters(`value clazzInterfaces`)
shared void getInterfaceHierarhyPropertyTest(Class<> clazz, Set<Interface<>> ifaces)
        => assertEquals(getInterfaceHierarchySet(clazz), ifaces);

test
shared void getInterfaceHierarhy_SouldNotGetIndirectIntefacesDerivedFromBaseType() {
    value actual = getInterfaceHierarchySet(`ClazzABC2`);
    assertEquals(actual, emptySet);
}

shared {[Type<>, [Parameter*]]*} typeDependencyList => [
    // basic types don't introspected
    [`String`,[]],
    [`Integer`,[]],
    [`Float`,[]],
    [`Boolean`,[]],
    [`Character`,[]],
    [`Basic`,[]],
    [`Object`,[]],
    [`Anything`, []],
    // interfaces can't have dependencies
    [`A`, []],
    [`ABC`, []],
    // class without dependencies
    [`ClazzA`, []],
    // class with two basic-types as dependencies
    [`Person`, [
        Parameter(`Person`, "name", `String`, false),
        Parameter(`Person`, "age", `Integer`, false)
    ]],
    // class with one class-dependency
    [`Box`, [Parameter(`Box`, "atom", `Atom`, false)]],
    // deep nested dependencies
    [`Matryoshka1`,
        [
            Parameter(`Matryoshka1`, "m2", `Matryoshka2`, false),
            Parameter(`Matryoshka2`, "m31", `Matryoshka3`, false),
            Parameter(`Matryoshka2`, "m32", `Matryoshka3`, false),
            Parameter(`Matryoshka3`, "m01", `Matryoshka0`, false),
            Parameter(`Matryoshka3`, "m02", `Matryoshka0`, false),
            Parameter(`Matryoshka3`, "m03", `Matryoshka0`, false),
            Parameter(`Matryoshka3`, "m01", `Matryoshka0`, false),
            Parameter(`Matryoshka3`, "m02", `Matryoshka0`, false),
            Parameter(`Matryoshka3`, "m03", `Matryoshka0`, false)
        ]
    ],
    // class with interface as dependency
    [`RuPostal`, [Parameter(`RuPostal`, "postman", `Postman`, false)]],
    // class with default dependency value (for interface dep)
    [`AsiaPostal`, [Parameter(`AsiaPostal`, "postman", `Postman`, true)]],
    // class with one union-type dependency, which have self depnendency
    [`Address`,
        [
            Parameter(`Address`, "street", `String|Street`, false),
            Parameter(`Street`, "name", `String`, true)
        ]
    ],
    // class with one intersection-type dependency
    [`RuPostalStore`, [Parameter(`RuPostalStore`, "employee", `Postman&Operator`, false)]],
    // generaic class with Type-parametrized nested dependencies
    [`GenericTanker<Integer, Float>`,
        [
            Parameter(`GenericTanker<Integer, Float>`, "box1", `GenericBox<Integer>`, false),
            Parameter(`GenericTanker<Integer, Float>`, "box2", `GenericBox<Float>`, false),
            Parameter(`GenericBox<Integer>`, "t", `Integer`, false),
            Parameter(`GenericBox<Float>`, "t", `Float`, false)
        ]
    ]

] ;

tag("x")
test parameters(`value typeDependencyList`)
shared void getDependencyGraphTest(Type<> t, [Parameter*] depsList) {
    assertEquals(getDependencySortedList(t), depsList);
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
    value registry = newRegistry();
//    registry.register(`Atom`);
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterType_whenRegistryInitiatedWithParams() {
    value registry = newRegistry {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterParams_whenRegistryInitiatedWithParams() {
    value registry = newRegistry {
        components = {`Box`};
        parameters = {[`Box`, "atom", Atom()]};
    };
    assertIs(registry.getInstance(`Box`), `Box`);
}

test
shared void registryShouldCreateInstance_ForTypeWithoutParameters() {
    value registry = newRegistry {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithoutParameters() {
    value registry = newRegistry {`Atom1`};
    assertIs(registry.getInstance(`Atom1`), `Atom1`);
}


test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithOneParameter() {
    value registry = newRegistry {`Atom`, `Box1`};
    assertIs(registry.getInstance(`Box1`), `Box1`);
}

test
shared void registryShouldCreateInstance_WithOneRegisteredDependencyType() {
    value registry = newRegistry();
//    registry.register(`Atom`);
//    registry.register(`Box`);
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCall() {
    value registry = newRegistry();
//    registry.register(Box(Atom()));
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInConstuctor() {
    value registry = newRegistry { Box(Atom()) };
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldCreateInstanceWithSomeSimpleParameters() {
    value registry = newRegistry {
        components = [`Person`];
        parameters = [
            [`Person`, "name", "Vika"],
            [`Person`, "age", 1]
        ];
    };

    value person = registry.getInstance(`Person`);
    assertIs(person, `Person`);
    assertEquals(person.name, "Vika");
    assertEquals(person.age, 1);
}

test
shared void registryShouldThrowExceptinWhenThereAreNoSomeParameters() {
    value registry = newRegistry {
        components = [`Person`];
        parameters = [
            [`Person`, "age", 1]
        ];
    };
    assertThatException(() => registry.getInstance(`Person`))
        .hasMessage("Registry.getInstance: can't createInstance for class <" +`Person`.string + ">");
}

tag("default")
test
shared void registryShouldCreateInstanceWithDefaultParameter() {
    value registry = newRegistry {`Box2`};
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
    value registry = newRegistry { `Matryoshka0`, `Matryoshka1`, `Matryoshka2`, `Matryoshka3` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

test
shared void registryShouldCreateDeeplyNestedInstancesWithDirectRefenecesAndWithoutExplicitRegistration() {
    value registry = newRegistry { `Matryoshka1` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

// ============================ CASE CLASS ================================

abstract class Fruit() of orange | apple { }
object apple extends Fruit() {}
object orange extends Fruit() {}

test
shared void registryShouldReturnInstanceForCaseClasses() {
    value registry = newRegistry { apple };
    value actual = registry.getInstance(`Fruit`);
    assertEquals(actual, apple);
}

//test
//shared void registryShouldReturnInstanceForCaseClasses1() {
//    value registry = newRegistry { `Fruit` };
//    value actual = registry.getInstance(`Fruit`);
//    assertEquals(actual, apple);
//}

// ============================ UNION TYPE ================================

class Street(String name = "noname") { }
class Address(String|Street street) { }

test
shared void registryShouldCreateInstanceWithUnionTypeDependency() {
    value registry = newRegistry { `Street`, `Address` };
    value actual = registry.getInstance(`Address`);
    assertIs(actual, `Address`);
}

// ============================ INTERSECTION TYPES ================================

interface Postman { }
interface Operator { }
class RuPostman() satisfies Postman & Operator { }
class RuPostman2() extends RuPostman() { }
class RuPostman3() extends RuPostman2() { }
class AsiaPostman() satisfies Postman { }
class RuPostal(shared Postman postman) { }
class RuPostalStore(shared Postman & Operator employee) { }
class AsiaPostal(shared Postman postman = AsiaPostman()) { }



test
shared void registryShouldCreateInstanceWithIntersectionTypeDependency() {
    value registry = newRegistry { `RuPostalStore`, `RuPostman`, `AsiaPostman` };
    value actual = registry.getInstance(`RuPostalStore`);
    assertIs(actual, `RuPostalStore`);
}

test
shared void registryShouldCreateInstanceWithIntersectionType() {
    value registry = newRegistry { `RuPostman`, `AsiaPostman` };
    value actual = registry.getInstance(`Operator&Postman`);
    assertIs(actual, `RuPostman`);
}

// ============================ GENERIC TYPES ================================


class GenericBox<T>(shared T t)  { }
class GenericTrackCar<T>(shared GenericBox<T> box)  { }
class GenericTanker<T,V>(GenericBox<T> box1, GenericBox<V> box2)  { }

tag("generic")
test
shared void registryShouldCreateInstanceWithOneGenericTypeDependency() {
    value registry = newRegistry { `GenericTrackCar<String>`, `GenericBox<String>`, "String item" };
    value actual = registry.getInstance(`GenericTrackCar<String>`);
    assertIs(actual, `GenericTrackCar<String>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependency() {
    value registry = newRegistry {
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
    value registry = newRegistry {
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
    value registry = newRegistry {
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
    value registry = newRegistry {
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
    value registry = newRegistry {
        `Bicycler<CrossBike>`,
        `CrossBike`
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

test
shared void registryShouldCreateInstanceWithoutRegistrationIfWeHaveDirectReferenceToClass() {
    value registry = newRegistry {
        `Bicycler<CrossBike>`// It's wonderfull - that we can create instances without registering it (if we have direct reference in constructor to classes and if they have default parameters)
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithExtendedTypeDependency() {
    value registry = newRegistry {
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
    value registry = newRegistry {`RuPostman`, `RuPostal`};
    value postal = registry.getInstance(`RuPostal`);
    assertIs(postal, `RuPostal`);
    assertIs(postal.postman, `RuPostman`);
}

tag("if")
test
shared void registryShouldCreateInstanceForGivenInterface() {
    value registry = newRegistry {`RuPostman`};
    value postman = registry.getInstance(`Postman`);
    assertIs(postman, `RuPostman`);
}

tag("if")
//tag("default")
test
shared void registryShouldCreateInstanceForGivenInterfaceWithItsDefaultParameter() {
    value registry = newRegistry {`AsiaPostal`};
    assertIs(registry.getInstance(`AsiaPostal`), `AsiaPostal`);
}

tag("if")
test
shared void registryShouldReturnSameInstanceForGivenTwoInterfaces() {
    value registry = newRegistry {`RuPostman`};
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
    value registry = newRegistry {`Dog`};
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
    value registry = newRegistry {
        components = [`DbService`, "users"];
        enchancers = [[`Service`, [`ServiceDbSchemaDecorator`]]];
        };
        value service = registry.getInstance(`Service`);
        assertIs(service, `ServiceDbSchemaDecorator`);
        assertEquals(service.connection, "users://users");
    }

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface() {
//    value registry = newRegistry { enchancers = [[`Service`, [`FakeDecorator`]]];};
    assertThatException(() => newRegistry { enchancers = [[`Service`, [`FakeDecorator`]]];})
    .hasMessage("Enchancer class <" + `FakeDecorator`.string +
                "> not compatible with origin class <" + `Service`.string +
                ">: missed interfaces { " + `Service`.string + " }");
}

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface2() {
//    value registry = newRegistry {`DbService`, "users"};
    assertThatException(() => newRegistry { enchancers = [[`Service`, [`FakeDecorator2`]]];})
    .hasMessage("Enhancer class <" + `FakeDecorator2`.string +
            "> must have at least one constructor parameter with <"
            + `Service`.string + "> or some of it interfaces {}");
}

tag("enhancer")
test
shared void registryShouldCreateInstanceWithTwoGivenEnchancers() {
    value registry = newRegistry {
        components = { DbService("users") };
        enchancers = {
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

