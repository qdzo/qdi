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
    Interface,
    InterfaceModel
}
import ceylon.test {
    test,
    assertIs,
    assertEquals,
    assertThatException,
    tag
}

Boolean loggingEnabled = true;
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
    components = HashMap<Type<>,Anything> {};

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

    {<Type<>->Anything>*} normalize({<Type<>|<Type<> -> Anything>>*} comps) => {
        for (comp in comps)
        switch(comp)
        case(is Type<Anything>) comp -> null
        else comp
    };

    {<Interface<>->Class<>>*} extractInterfacesFromClasses({Type<>*} types) => {
        for (clazz in types)
        if(is Class<> clazz, nonempty interfaces = clazz.satisfiedTypes)
        interfaces.map((InterfaceModel<> iface) => iface.declaration.interfaceApply<Anything>() -> clazz)
    }.flatMap(identity);

    shared new(
            {<Type<>|<Type<> -> Anything>>*} components = empty,
            {[Type<>, String, Anything]*} parameters = empty) {

        value normalized = normalize(components);
        this.components.putAll(normalized);
        this.interfaceComponents.putAll(extractInterfacesFromClasses(normalized.map(Entry.key)));
        this.parameters.putAll({ for ([type, paramName, val] in parameters) [type, paramName] -> val });
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
        components.put(t, val);
        interfaceComponents.putAll(extractInterfacesFromClasses({t}));
    }

    // TODO: new replacement for register method
    shared void register2<T>(Class<T>|Object typeOrInstance) {
        value [clazz, val] = switch (typeOrInstance)
        case (is Class<>) [typeOrInstance, null]
        else [type(typeOrInstance).declaration.classApply<Anything>(), typeOrInstance];
        components.put(clazz, val);
        print("Registry.register2: register " + (if(exists val) then "instance: <``val``> for " else "") + "type <``clazz``>");
        interfaceComponents.putAll(extractInterfacesFromClasses({clazz}));
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
shared void registryShouldRegisterType_whenRegisterCalled() {
    value registry = Registry();
    registry.register2(`Atom`);
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
    registry.register2(`Atom`);
    registry.register2(`Box`);
    value box = registry.getInstance(`Box`);
    assertIs(box, `Box`);
}

test
shared void registryShouldRegisterTypeWithInstanceInRegisterMethodCalled() {
    value registry = Registry();
//    registry.register(`Box`, Box(Atom()));
    registry.register2(Box(Atom()));
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
    assertIs(registry.getInstance(`Matryoshka1`), `Matryoshka1`);
}

test
shared void registryShouldCreateInstanceWithDefaultParameter() {
    value registry = Registry {`Box2`};
    assertIs(registry.getInstance(`Box2`), `Box2`);
}

// --------------------------------------------------------------------------

interface Postman { }
class RuPostman() satisfies Postman { }
class AsiaPostman() satisfies Postman { }
class RuPostal(shared Postman postman)  { }
class AsiaPostal(shared Postman postman = AsiaPostman())  { }

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
