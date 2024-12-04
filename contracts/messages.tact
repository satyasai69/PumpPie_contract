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
    tokenAddress: Address;
    tokenAmount: Int;
}

message SellTokens {
    tokenAddress: Address;
    tokenAmount: Int;
}
