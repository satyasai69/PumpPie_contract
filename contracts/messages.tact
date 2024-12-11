message RegisterToken {
    tokenAddress: Address;
}

message VerifyJetton {
    queryId: Int as uint64;
    tokenAddress: Address;
}

message JettonVerified {
    queryId: Int as uint64;
    isJetton: Bool;
    tokenAddress: Address;
}

message BuyTokens {
   // tokenAddress: Address;
    tokenAmount: Int;
}

message SellTokens {
   // tokenAddress: Address;
    tokenAmount: Int;
}

message PoolBuy {
    jettonAddress: Address;
    amount: Int as coins;
}

message PoolSell {
    jettonAddress: Address;
    to: Address;
    amount: Int as coins;
}

message AddJetton {
    jettonAddress: Address;
}
