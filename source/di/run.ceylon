import ceylon.collection {
    MutableMap,
    HashMap
}
import ceylon.language.meta.declaration {
    OpenClassOrInterfaceType,
    OpenClassType
}
import ceylon.language.meta.model {
    Type,
    Class
}
import ceylon.test {
    test,
    assertIs,
    assertEquals,
    assertThatException
}
import ceylon.language { ceylonPrint = print }

Boolean loggingEnabled = false;
void print(Anything val) {
    if(loggingEnabled) {
        ceylonPrint(val);
    }
}
// ----------------------------------------------------

class Person(shared String name, shared Integer age)  {
    string = "Person(name = ``name``, age = ``age``)";
}

class Atom() { string = "Atom()"; }

class Atom1 {
    shared new () {}
    string = "Atom1()";
}

class Atom2(shared Integer i) { string = "Atom2(``i``)"; }

class Dog(shared String nichName, shared Person owner)  {
    string = "Dog(nichName = ``nichName``, owner = ``owner``)";
}

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
// ----------------------------------------------------

class Registry {

    MutableMap<[Type<>, String],Anything>
    parameters = HashMap<[Type<>, String], Anything> {};

    MutableMap<Type<>, Anything>
    container = HashMap<Type<>,Anything> {};

    shared new({<Type<>|<Type<> -> Anything>>*} initial = empty) {
        container.putAll(
            {
                for (element in initial)
                switch(element)
                case(is Type<Anything>) element -> null
                else element
            }
        );
    }

    class Parameter(
            shared String name,
            shared OpenClassOrInterfaceType type,
            shared Boolean defaulted
            )  { }

    shared void registerParameter<T>(Class<T> t, String param, Anything val) {
        print("Registry.registerParameter: for type <``t``>, name: <``param``>, val: <``val else "null"``>");
        parameters.put([t, param], val);
    }

    shared void register<T>(Type<T> t, T? val = null) {
        print("Registry.register: register type: <``t``> with val: <``val else "null"``>");
        container.put(t, val);
    }

    T tryToCreateInstance<T>(Class<T> t) {
        try {
            print("Registry.tryToCreateInstance: class <``t``>");
            value paramsWithTypes = constructorParameters(t);
            if (paramsWithTypes.empty) {
                print("Registry.tryToCreateInstance: default constructor for type <``t``> is without parameters");
                value instance = t.apply();
                print("Registry.tryToCreateInstance: instance created for type <``t``>");
                return instance;
            }
            print("Registry.tryToCreateInstance: default constructor for type <``t``> has ``paramsWithTypes.size`` parameters");
            value params = instantiateParams(t, paramsWithTypes);
            print("Registry.tryToCreateInstance: try to instantiate type <``t``>");
            value instance = t.namedApply(params);
            print("Registry.tryToCreateInstance: instance created for type <``t``>");
            return instance;
        } catch(Throwable th) {
            value errorMsg = "Can't create instance: ``th.message``";
            print("Registry.tryToCreateInstance: ``errorMsg``");
            throw Exception(errorMsg);
        }
    }

    shared T getInstance<T>(Type<T> t) {
        print("Registry.getInstance: for type <``t``>");
        assert(is Class<T> t);
        if (container.defines(t)) {
            print("Registry.getInstance: container has registered type <``t``>");
            if (exists instance = container.get(t)) {
                print("Registry.getInstance: container has instance for type <``t``>");
                assert (is T instance);
                return instance;
            } else {
                print("Registry.getInstance: container has not instance for type <``t``>");
                value instance = tryToCreateInstance(t);
                container.put(t, instance);
                return instance;
            }
        }
        print("Registry.getInstance: container has not registered type ``t``");
        throw Exception("There are no such type in Registry <``t``>");
    }

    {<String->Anything>*}
    instantiateParams<T>(Class<T> t, {Parameter*} paramsTypes)
            => paramsTypes.map (
                (Parameter parameter) {
                    if(exists paramVal = parameters[[t, parameter.name]]) {
                        return parameter.name -> paramVal;
                    } else {
                        assert(is OpenClassType item = parameter.type);
                        value decl = item.declaration.classApply<Anything>();
                        try {
                            value depInstance = getInstance(decl);
                            return parameter.name -> depInstance;
                        } catch (Throwable th) {
                            if(parameter.defaulted) {
                                return null;
                            }
                            throw Exception("");
                        }

                    }
                }
    ).coalesced;

    {Parameter*} constructorParameters<T>(Type<T> t) {

        assert(is Class<T> t);
        assert(exists parameterDeclarations
                = t.defaultConstructor?.declaration?.parameterDeclarations);

        {Parameter*} params = parameterDeclarations.map((e) {
            assert(is OpenClassOrInterfaceType openType = e.openType);
            return Parameter(e.name, openType, e.defaulted);
        });
        return params;
    }
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
////    value params = constructorParameters(`Person`);
////    value params = constructorParameters(`Person`);
////    print(params);
////    print(`Person`.defaultConstructor?.namedApply({"name"-> "Vitaly", "age"-> 31}));
//}

test
shared void emptyRegistry_ShouldRegisterAndCreateInstanceForTypeWithoutDependencies_WhenRegisterAndGetInstanceCalled() {
    value registry = Registry();
    registry.register(`Atom`);
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void oneItemRegistry_ShouldRegisterAndCreateInstanceForTypeWithoutDependencies_WhenGetInstanceCalled() {
    value registry = Registry {`Atom`};
    assertIs(registry.getInstance(`Atom`), `Atom`);
}

test
shared void registryShouldCreateInstanceForTypeWithExplicitConstructorWithoutParameters() {
    value registry = Registry();
    registry.register(`Atom1`);
    assertIs(registry.getInstance(`Atom1`), `Atom1`);
}


test
shared void registryShouldCreateInstanceForTypeWithExplicitConstructorWithOneParameter() {
    value registry = Registry();
    registry.register(`Atom`);
    registry.register(`Box1`);
    value box = registry.getInstance(`Box1`);
    assertIs(box, `Box1`);
}

test
shared void registryShouldCreateInstanceWithOneRegisteredDependencyType() {
    value registry = Registry();
    registry.register(`Atom`);
    registry.register(`Box`);
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCalled() {
    value registry = Registry();
    registry.register(`Box`, Box(Atom()));
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInConstuctor() {
    value registry = Registry {`Box`-> Box(Atom())};
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldCreateInstanceWithSomeSimpleParameters() {
    value registry = Registry { `Person` };
    registry.registerParameter(`Person`, "name", "Vika");
    registry.registerParameter(`Person`, "age", 18);
    value person = registry.getInstance(`Person`);
    assertIs(person, `Person`);
    assertEquals(person.name, "Vika");
    assertEquals(person.age, 18);
}

test
shared void registryShouldThrowExceptinWhenThereAreNoSomeParameters() {
    value registry = Registry { `Person` };
    registry.registerParameter(`Person`, "age", 18);
    assertThatException(() => registry.getInstance(`Person`));
}

test
shared void registryShouldCreateDeeplyNestedInstances() {
    value registry = Registry { `Matryoshka0`, `Matryoshka1`, `Matryoshka2`, `Matryoshka3` };
    value box = registry.getInstance(`Matryoshka1`);
    assertIs(box, `Matryoshka1`);
}

test
shared void registryShouldCreateInstanceWithItsDefaultParameter() {
    value registry = Registry {`Box`, `Atom`};
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}
