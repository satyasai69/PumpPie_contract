import { toNano, Address } from '@ton/core';
import { NetworkProvider, sleep } from '@ton/blueprint';
import { PoolCore } from '../wrappers/PoolCore';

const PoolCore_ADDRESS = "EQCcPJDVADLxcRbs641KdW6stQg8b9jwCbkBktA2dREYExpD";

export async function run(provider: NetworkProvider, args: string[]) {
    const ui = provider.ui();

    const address = Address.parse(PoolCore_ADDRESS);

    if (!address) {
        ui.write(`Invalid PoolCore address`);
        return;
    }

    const poolCore = provider.open(PoolCore.fromAddress(address));

    // Get all pools
    const pools = await poolCore.getGetAllPools();
    
    ui.write('All Pools:');
    for (const [address, pool] of pools) {
        ui.write(`\nPool Address: ${address.toString()}`);
        ui.write(`Balance: ${pool.balance} TON`);
        ui.write(`Active: ${pool.isActive}`);
    }
}
