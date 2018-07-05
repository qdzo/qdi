import ceylon.logging {
	addLogWriter,
	writeSimpleLog,
	defaultPriority,
	trace
}
import ceylon.test {
	beforeTestRun,
	test,
	assertEquals,
	assertIs,
	assertThatException,
	tag
}

import com.github.qdzo.qdi {
	describeClass,
	getClassHierarchyExceptBasicClasses,
	getInterfaceHierarhy,
	RegistryImpl
}
beforeTestRun
shared void setupLogger() {
//    addLogWriter(writeSimpleLog);
//    defaultPriority =
//             trace
//             info
//    ;
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
    value registry = RegistryImpl();
    registry.register(`Atom`);
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterType_whenRegistryInitiatedWithParams() {
    value registry = RegistryImpl {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldRegisterParams_whenRegistryInitiatedWithParams() {
    value registry = RegistryImpl {
        components = {`Box`};
        parameters = {[`Box`, "atom", Atom()]};
    };
    assertIs(registry.getInstance(`Box`), `Box`);
}

test
shared void registryShouldCreateInstance_ForTypeWithoutParameters() {
    value registry = RegistryImpl {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithoutParameters() {
    value registry = RegistryImpl {`Atom1`};
    assertIs(registry.getInstance(`Atom1`), `Atom1`);
}


test
shared void registryShouldCreateInstance_ForTypeWithExplicitConstructorWithOneParameter() {
    value registry = RegistryImpl {`Atom`, `Box1`};
    assertIs(registry.getInstance(`Box1`), `Box1`);
}

test
shared void registryShouldCreateInstance_WithOneRegisteredDependencyType() {
    value registry = RegistryImpl();
    registry.register(`Atom`);
    registry.register(`Box`);
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCall() {
    value registry = RegistryImpl();
    registry.register(Box(Atom()));
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInConstuctor() {
    value registry = RegistryImpl { Box(Atom()) };
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldCreateInstanceWithSomeSimpleParameters() {
    value registry = RegistryImpl { `Person` };
    registry.registerParameter(`Person`, "name", "Vika");
    registry.registerParameter(`Person`, "age", 1);
    value person = registry.getInstance(`Person`);
    assertIs(person, `Person`);
    assertEquals(person.name, "Vika");
    assertEquals(person.age, 1);
}

test
shared void registryShouldThrowExceptinWhenThereAreNoSomeParameters() {
    value registry = RegistryImpl { `Person` };
    registry.registerParameter(`Person`, "age", 1);
    assertThatException(() => registry.getInstance(`Person`))
        .hasMessage("Registry.getInstance: can't createInstance for class <" +`Person`.string + ">");
}

tag("default")
test
shared void registryShouldCreateInstanceWithDefaultParameter() {
    value registry = RegistryImpl {`Box2`};
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
    value registry = RegistryImpl { `Matryoshka0`, `Matryoshka1`, `Matryoshka2`, `Matryoshka3` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

test
shared void registryShouldCreateDeeplyNestedInstancesWithDirectRefenecesAndWithoutExplicitRegistration() {
    value registry = RegistryImpl { `Matryoshka1` };
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

// ============================ CASE CLASS ================================

abstract class Fruit() of orange | apple { }
object apple extends Fruit() {}
object orange extends Fruit() {}

test
shared void registryShouldReturnInstanceForCaseClasses() {
    value registry = RegistryImpl { apple };
    value actual = registry.getInstance(`Fruit`);
    assertEquals(actual, apple);
}

//test
//shared void registryShouldReturnInstanceForCaseClasses1() {
//    value registry = RegistryImpl { `Fruit` };
//    value actual = registry.getInstance(`Fruit`);
//    assertEquals(actual, apple);
//}

// ============================ UNION TYPE ================================

class Street() { }
class Address(String|Street street) { }

test
shared void registryShouldCreateInstanceWithUnionTypeDependency() {
    value registry = RegistryImpl { `Street`, `Address` };
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
    value registry = RegistryImpl { `RuPostalStore`, `RuPostman`, `AsiaPostman` };
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
    value registry = RegistryImpl { `GenericTrackCar<String>`, `GenericBox<String>`, "String item" };
    value actual = registry.getInstance(`GenericTrackCar<String>`);
    assertIs(actual, `GenericTrackCar<String>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithTwoGenericTypeDependency() {
    value registry = RegistryImpl {
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
    value registry = RegistryImpl {
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
    value registry = RegistryImpl {
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
    value registry = RegistryImpl {
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
    value registry = RegistryImpl {
        `Bicycler<CrossBike>`,
        `CrossBike`
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

tag("repl")
test
shared void registryShouldCreateInstanceWithoutRegistrationIfWeHaveDirectReferenceToClass() {
    value registry = RegistryImpl {
        `Bicycler<CrossBike>`// It's wonderfull - that we can create instances without registering it (if we have direct reference in constructor to classes and if they have default parameters)
    };
    value actual = registry.getInstance(`Bicycler<CrossBike>`);
    assertIs(actual, `Bicycler<CrossBike>`);
}

tag("generic")
test
shared void registryShouldCreateInstanceWithExtendedTypeDependency() {
    value registry = RegistryImpl {
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
    value registry = RegistryImpl {`RuPostman`, `RuPostal`};
    value postal = registry.getInstance(`RuPostal`);
    assertIs(postal, `RuPostal`);
    assertIs(postal.postman, `RuPostman`);
}

tag("if")
test
shared void registryShouldCreateInstanceForGivenInterface() {
    value registry = RegistryImpl {`RuPostman`};
    value postman = registry.getInstance(`Postman`);
    assertIs(postman, `RuPostman`);
}

tag("if")
//tag("default")
test
shared void registryShouldCreateInstanceForGivenInterfaceWithItsDefaultParameter() {
    value registry = RegistryImpl {`AsiaPostal`};
    assertIs(registry.getInstance(`AsiaPostal`), `AsiaPostal`);
}

tag("if")
test
shared void registryShouldReturnSameInstanceForGivenTwoInterfaces() {
    value registry = RegistryImpl {`RuPostman`};
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
    value registry = RegistryImpl {`Dog`};
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
    value registry = RegistryImpl {`DbService`, "users"};
    registry.registerEnhancer(`Service`, [`ServiceDbSchemaDecorator`]);
    value service = registry.getInstance(`Service`);
    assertIs(service, `ServiceDbSchemaDecorator`);
    assertEquals(service.connection, "users://users");
}

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface() {
    value registry = RegistryImpl {`Service`, "users"};
    assertThatException(() => registry.registerEnhancer(`Service`, [`FakeDecorator`]))
    .hasMessage("Enchancer class <" + `FakeDecorator`.string +
                "> not compatible with origin class <" + `Service`.string +
                ">: missed interfaces { " + `Service`.string + " }");
}

tag("enhancer")
test
shared void registryShouldThrowExceptionWhenRegisterEnchancerWithWrongInterface2() {
    value registry = RegistryImpl {`DbService`, "users"};
    assertThatException(() => registry.registerEnhancer(`Service`, [`FakeDecorator2`]))
    .hasMessage("Enhancer class <" + `FakeDecorator2`.string +
            "> must have at least one constructor parameter with <"
            + `Service`.string + "> or some of it interfaces []");
}

tag("now")
tag("enhancer")
test
shared void registryShouldCreateInstanceWithTwoGivenEnchancers() {
    value registry = RegistryImpl {
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

