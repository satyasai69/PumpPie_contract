import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type PoolConfig = {
    owner: Address;
    tokenAddress: Address;
};

export function poolConfigToCell(config: PoolConfig): Cell {
    return beginCell()
        .storeAddress(config.owner)
        .storeAddress(config.tokenAddress)
        .endCell();
}

export class Pool implements Contract {
    constructor(
        readonly address: Address,
        readonly init?: { code: Cell; data: Cell },
    ) {}

    static createFromAddress(address: Address) {
        return new Pool(address);
    }

    static createFromConfig(config: PoolConfig, code: Cell, workchain = 0) {
        const data = poolConfigToCell(config);
        const init = { code, data };
        return new Pool(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }

    async sendBuyTokens(
        provider: ContractProvider,
        via: Sender,
        opts: {
            value: bigint;
        }
    ) {
        await provider.internal(via, {
            value: opts.value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(0x595f07bc, 32) // op for BuyTokens
                .endCell(),
        });
    }

    async sendSellTokens(
        provider: ContractProvider,
        via: Sender,
        opts: {
            amount: bigint;
            from: Address;
            value: bigint;
        }
    ) {
        await provider.internal(via, {
            value: opts.value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(0x737bdf58, 32) // op for SellTokens
                .storeCoins(opts.amount)
                .storeAddress(opts.from)
                .endCell(),
        });
    }

    // Get methods

    async getTokenData(provider: ContractProvider) {
        const result = await provider.get('getTokenData', []);
        return {
            total_supply: result.stack.readBigNumber(),
            mintable: result.stack.readBoolean(),
            admin_address: result.stack.readAddress(),
            jetton_content: result.stack.readCell(),
            jetton_wallet_code: result.stack.readCell(),
        };
    }

    async getTokenSupply(provider: ContractProvider) {
        const result = await provider.get('getTokenSupply', []);
        return result.stack.readBigNumber();
    }
}