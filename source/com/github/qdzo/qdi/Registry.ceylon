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
 - They need to have at least one parameter with interface, that they wrappes
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

	"Add new `class or instance` to registry and return that registry"
	shared formal Registry register<T>(Class<T>|Object classOrInstance);

	"Add new enhancers for given interface"
    throws(`class Exception`, "when enhancer don't comforms to the rules")
	shared formal Registry registerEnhancer<T>(
			"Target interface to wrap with enhancers"
			Interface<T> target,
			"Ordered list of enhancers:
             - Enhancers need to be with the same interface.
             - Every next enhancer wraps previous."
			Enhancers enhancers);

    "Add new direct parameter for given class"
    shared formal Registry registerParameter<T>(
            "Target class for injecing parameter"
            Class<T> target,
            "Constructor paramerter name"
            ParameterName param,
            "Value to inject.
             Values have highest priority for injection"
            ValueToInject val);

}