import ceylon.language.meta.model {
	Type,
	Interface,
	Class
}

shared interface Registry {

	shared formal T getInstance<T>(Type<T> t);

	shared formal Registry register<T>(Class<T>|Object typeOrInstance);

	shared formal Registry registerEnhancer<T>(Interface<T> target, [Class<>+] wrappers);

	shared formal Registry registerParameter<T>(Class<T> target, String param, Anything val);

}