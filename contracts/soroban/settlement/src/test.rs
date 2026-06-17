#![cfg(test)]

use super::*;
use soroban_sdk::testutils::{Address as _, BytesN as _};
use soroban_sdk::{token, Address, BytesN, Env};

struct Setup {
    env: Env,
    contract_id: Address,
    client: SettlementClient<'static>,
    endpoint: Address,
    asset: Address,
    asset_admin: token::StellarAssetClient<'static>,
}

fn setup() -> Setup {
    let env = Env::default();
    env.mock_all_auths();

    let admin = Address::generate(&env);
    let endpoint = Address::generate(&env);

    let contract_id = env.register(Settlement, ());
    let client = SettlementClient::new(&env, &contract_id);
    client.initialize(&admin, &endpoint);

    // Deploy a Stellar Asset Contract and pre-fund the settlement contract.
    let issuer = Address::generate(&env);
    let sac = env.register_stellar_asset_contract_v2(issuer);
    let asset = sac.address();
    let asset_admin = token::StellarAssetClient::new(&env, &asset);
    asset_admin.mint(&contract_id, &1_000_000);

    Setup {
        env,
        contract_id,
        client,
        endpoint,
        asset,
        asset_admin,
    }
}

fn message(env: &Env, recipient: &Address, asset: &Address, amount: i128) -> BridgeMessage {
    BridgeMessage {
        intent_hash: BytesN::random(env),
        src_eid: 30101,
        recipient: recipient.clone(),
        asset: asset.clone(),
        amount,
    }
}

#[test]
fn settles_and_releases_funds() {
    let s = setup();
    let user = Address::generate(&s.env);
    let msg = message(&s.env, &user, &s.asset, 250_000);

    assert!(!s.client.is_settled(&msg.intent_hash));
    s.client.lz_receive(&msg);

    let token = token::Client::new(&s.env, &s.asset);
    assert_eq!(token.balance(&user), 250_000);
    assert_eq!(token.balance(&s.contract_id), 750_000);
    assert!(s.client.is_settled(&msg.intent_hash));
}

#[test]
#[should_panic(expected = "Error(Contract, #4)")] // AlreadySettled
fn rejects_replay() {
    let s = setup();
    let user = Address::generate(&s.env);
    let msg = message(&s.env, &user, &s.asset, 100);

    s.client.lz_receive(&msg);
    s.client.lz_receive(&msg); // replay -> panic
}

#[test]
#[should_panic(expected = "Error(Contract, #5)")] // InvalidAmount
fn rejects_zero_amount() {
    let s = setup();
    let user = Address::generate(&s.env);
    let msg = message(&s.env, &user, &s.asset, 0);
    s.client.lz_receive(&msg);
}

#[test]
#[should_panic(expected = "Error(Contract, #1)")] // AlreadyInitialized
fn rejects_double_initialize() {
    let s = setup();
    let admin = Address::generate(&s.env);
    s.client.initialize(&admin, &s.endpoint);
}

#[test]
fn admin_can_rotate_endpoint() {
    let s = setup();
    let new_endpoint = Address::generate(&s.env);
    s.client.set_endpoint(&new_endpoint);
    assert_eq!(s.client.endpoint(), new_endpoint);
    // Silence unused warning for the funding admin client.
    let _ = &s.asset_admin;
}
