#![no_std]
//! # Perihelion Settlement Contract
//!
//! The Stellar-side endpoint of the Perihelion bridge. It receives verified
//! cross-chain messages (relayed via LayerZero) attesting that a solver locked a
//! user's funds on a source chain, and releases the corresponding assets to the
//! user's Stellar address.
//!
//! ## Trust model
//! Only the configured LayerZero endpoint may invoke [`Settlement::lz_receive`].
//! Each intent is settled at most once: the intent hash is recorded on first
//! settlement and any replay reverts. Funds released come from this contract's
//! own balance, which solvers / the protocol pre-fund per supported asset.

use soroban_sdk::{
    contract, contracterror, contractimpl, contracttype, token, Address, BytesN, Env, Symbol,
};

/// Cross-chain settlement instruction delivered by the LayerZero endpoint.
#[contracttype]
#[derive(Clone)]
pub struct BridgeMessage {
    /// keccak256 commitment of the originating intent (its protocol-wide id).
    pub intent_hash: BytesN<32>,
    /// LayerZero endpoint id of the source chain.
    pub src_eid: u32,
    /// Stellar account/contract that receives the released assets.
    pub recipient: Address,
    /// Token contract (Stellar Asset Contract) to release.
    pub asset: Address,
    /// Amount to release, in the asset's smallest unit.
    pub amount: i128,
}

/// Persistent storage keys.
#[contracttype]
pub enum DataKey {
    /// Contract admin (governance / upgrades).
    Admin,
    /// The sole address permitted to deliver messages (LayerZero endpoint).
    Endpoint,
    /// Marker that a given intent hash has been settled (replay guard).
    Settled(BytesN<32>),
}

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
#[repr(u32)]
pub enum Error {
    AlreadyInitialized = 1,
    NotInitialized = 2,
    Unauthorized = 3,
    AlreadySettled = 4,
    InvalidAmount = 5,
}

#[contract]
pub struct Settlement;

#[contractimpl]
impl Settlement {
    /// Initialize the contract with an admin and the trusted LayerZero endpoint.
    pub fn initialize(env: Env, admin: Address, endpoint: Address) -> Result<(), Error> {
        let storage = env.storage().instance();
        if storage.has(&DataKey::Admin) {
            return Err(Error::AlreadyInitialized);
        }
        storage.set(&DataKey::Admin, &admin);
        storage.set(&DataKey::Endpoint, &endpoint);
        Ok(())
    }

    /// Update the trusted LayerZero endpoint. Admin-only.
    pub fn set_endpoint(env: Env, new_endpoint: Address) -> Result<(), Error> {
        let admin = Self::require_admin(&env)?;
        admin.require_auth();
        env.storage()
            .instance()
            .set(&DataKey::Endpoint, &new_endpoint);
        Ok(())
    }

    /// Receive a verified cross-chain message and release assets to the
    /// recipient. Callable only by the configured endpoint; settles each intent
    /// at most once.
    pub fn lz_receive(env: Env, msg: BridgeMessage) -> Result<(), Error> {
        let endpoint: Address = env
            .storage()
            .instance()
            .get(&DataKey::Endpoint)
            .ok_or(Error::NotInitialized)?;
        endpoint.require_auth();

        if msg.amount <= 0 {
            return Err(Error::InvalidAmount);
        }

        let settled_key = DataKey::Settled(msg.intent_hash.clone());
        if env.storage().persistent().has(&settled_key) {
            return Err(Error::AlreadySettled);
        }
        env.storage().persistent().set(&settled_key, &true);

        // Release assets from this contract's pre-funded balance to the user.
        let client = token::Client::new(&env, &msg.asset);
        client.transfer(
            &env.current_contract_address(),
            &msg.recipient,
            &msg.amount,
        );

        env.events().publish(
            (Symbol::new(&env, "settled"), msg.intent_hash.clone()),
            (msg.recipient, msg.asset, msg.amount, msg.src_eid),
        );
        Ok(())
    }

    /// True if the given intent has already been settled.
    pub fn is_settled(env: Env, intent_hash: BytesN<32>) -> bool {
        env.storage()
            .persistent()
            .has(&DataKey::Settled(intent_hash))
    }

    /// Current trusted endpoint address.
    pub fn endpoint(env: Env) -> Result<Address, Error> {
        env.storage()
            .instance()
            .get(&DataKey::Endpoint)
            .ok_or(Error::NotInitialized)
    }

    fn require_admin(env: &Env) -> Result<Address, Error> {
        env.storage()
            .instance()
            .get(&DataKey::Admin)
            .ok_or(Error::NotInitialized)
    }
}

#[cfg(test)]
mod test;
