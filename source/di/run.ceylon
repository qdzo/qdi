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
    OpenClassOrInterfaceType,
    OpenClassType
}
import ceylon.language.meta.model {
    Type,
    Class,
    Interface
}
import ceylon.test {
    test,
    assertIs,
    assertEquals,
    assertThatException,
    tag
}

Boolean loggingEnabled = false;
void print(Anything val) {
    if(loggingEnabled) {
        ceylonPrint(val);
    }
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


    MutableMap<[Type<>, String],Anything>
    parameters = HashMap<[Type<>, String], Anything> {};

    MutableMap<Type<>, Anything>
    components = HashMap<Type<>,Anything> {};

    MutableMap<Type<>, Class<>>
    extendComponents = HashMap<Type<>, Class<>> {};

    MutableMap<Interface<>, Class<>>
    interfaceComponents = HashMap<Interface<>, Class<>> {};

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
            {[Type<>, String, Anything]*} parameters = empty) {

        value described = components.map(describeComponent);
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
            shared OpenClassOrInterfaceType type,
            shared Boolean defaulted
            )  { }

    shared void registerParameter<T>(Class<T> t, String param, Anything val) {
        print("Registry.registerParameter: for type <``t``>, name: <``param``>, val: <``val else "null"``>");
        parameters.put([t, param], val);
    }

    shared void register<T>(Class<T>|Object typeOrInstance) {
        value [inst, clazz, extClazz, ifaces] = describeComponent(typeOrInstance);
        components.put(clazz, inst);
        extendComponents.put(extClazz, clazz);
        print("Registry.register2: register " + (if(exists inst) then "instance: <``inst``> for " else "") + "type <``clazz``>");
        interfaceComponents.putAll { for (iface in ifaces) iface -> clazz };
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
        } catch(Exception th) {
            value errorMsg = "Can't create instance: ``th.message``";
            print("Registry.tryToCreateInstance: ``errorMsg``");
            throw Exception(errorMsg);
        }
    }

    T instantiateClass<T>(Class<T> t) {
        if (components.defines(t)) {
            print("Registry.getInstance: components has registered type <``t``>");
            if (exists instance = components.get(t)) {
                print("Registry.getInstance: components has instance for type <``t``>");
                assert (is T instance);
                return instance;
            } else {
                print("Registry.getInstance: components has not instance for type <``t``>");
                value instance = tryToCreateInstance(t);
                components.put(t, instance);
                return instance;
            }
        } else if (exists tt = extendComponents[t]) {
            value instance = instantiateClass(tt);
            assert (is T instance);
            return instance;
        }
        print("Registry.getInstance: components has not registered type ``t``");
        throw Exception("There are no such type in Registry <``t``>");
    }

    shared T getInstance<T>(Type<T> t) {
        print("Registry.getInstance: for type <``t``>");
        if (is Interface<T> t) {
            if(is Class<T> satisfiedClass = interfaceComponents.get(t)) {
                print("Registry.getInstance: has registered type for interface <``t``>");
                return instantiateClass(satisfiedClass);
            }
        }
        else if(is Class<T> t) {
            return instantiateClass(t);
        }
        throw Exception("Type is not interface nor class: <``t``>");
    }

    {<String->Anything>*}
    instantiateParams<T>(Class<T> t, {Parameter*} paramsTypes)
            => paramsTypes.map (
                (Parameter parameter) {
                    if(exists paramVal = parameters[[t, parameter.name]]) {
                        return parameter.name -> paramVal;
                    } else {
                        value paramType = parameter.type;
                        value decl = if(is OpenClassType paramType)
                                     then paramType.declaration.classApply<Anything>()
                                     else paramType.declaration.interfaceApply<Anything>();
                        try {
                            value depInstance = getInstance(decl);
                            return parameter.name -> depInstance;
                        } catch (Exception th) {
                            if(parameter.defaulted) {
                                return null;
                            }
                            throw Exception("");
                        }

                    }
                }
    ).coalesced;

    {Parameter*} constructorParameters<T>(Class<T> t) {
        assert(exists parameterDeclarations
                = t.defaultConstructor?.declaration?.parameterDeclarations);
        return parameterDeclarations.map((e) {
            assert(is OpenClassOrInterfaceType openType = e.openType);
            return Parameter(e.name, openType, e.defaulted);
        });
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
                => iface.declaration.interfaceApply<Anything>())
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
    case(is Class<Anything>) [null, *describeClass(comp)]
    else  describeInstance(comp);

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
//    registry.register(`Box`, Box(Atom()));
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
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

test
shared void registryShouldCreateInstanceWithDefaultParameter() {
    value registry = Registry {`Box2`};
    assertIs(registry.getInstance(`Box2`), `Box2`);
}

// ============================ INTERFACES ================================

interface Postman { }
interface Operator { }
class RuPostman() satisfies Postman & Operator { }
class AsiaPostman() satisfies Postman { }
class RuPostal(shared Postman postman) { }
class AsiaPostal(shared Postman postman = AsiaPostman()) { }


// ============================ CASE CLASS ================================

abstract class Fruit() of orange | apple { }
object apple extends Fruit() {}
object orange extends Fruit() {}

// ============================ ABSTRACT CLASS ================================

abstract class Animal() {}
class Dog() extends Animal() { }
class Cat() extends Animal() { }

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

tag("abstract")
test
shared void registryShouldCreateInstanceForAbstractClass() {
    value registry = Registry {`Dog`};
    value animal = registry.getInstance(`Animal`);
    assertIs(animal, `Dog`);
}

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

test
shared void describeInstance_SouldReturnCorrectInfo_ForCaseClass() {
    value actual = describeInstance(orange);
    assertEquals(actual[0], orange);
    // orange is class orange with signleton object
    assertEquals(actual[1],  type(orange));
    assertEquals(actual[2], `Fruit`);
    assertEquals(actual[3], []);
}

