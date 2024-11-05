module volo::cert {

    public struct CERT has drop {}

    public struct Metadata<phantom T> has key, store {
        id: UID,
    }
}
