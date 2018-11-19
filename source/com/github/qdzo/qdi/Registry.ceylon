import ceylon.language.meta.model {
	Type,
	Interface,
	Class
}

"Custom value, that will be injected."
shared alias ValueToInject => Anything;

"String, representing constructor parameter-name"
shared alias ParameterName => String;

"Ordered list of enhancer declarations:
 - Enhancers need to be with the same interface.
 - They need to have at least one parameter with interface, that they wrap
 - Every next enhancer wraps previous."
shared alias Enhancers => [Class<>+];

"Registry is simple constructor-based dependency-injection container.
 - Can create instantces from registered components.
 - Can register new instances or classes or enhancers for future use.
 - Wraps instances before returning them with wrappers (decorators)"
shared interface Registry {

	"Try to create instance for given type (class/interface/union/intersection)"
	throws(`class Exception`, "When can't create instance.")
	shared formal T getInstance<T>(Type<T> t);
    
    "Patch current registry with given and returns new-one - already patched"
    shared formal Registry patch(Registry registry);
}