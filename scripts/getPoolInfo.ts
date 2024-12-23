import { toNano, Address } from '@ton/core';
import { NetworkProvider, sleep } from '@ton/blueprint';
import { PoolCore } from '../wrappers/PoolCore';

const PoolCore_ADDRESS = "EQCcPJDVADLxcRbs641KdW6stQg8b9jwCbkBktA2dREYExpD";
const JETTON_ADDRESS = "EQAlUDRK_ZrEjy2F250_1z7S_5sCHvo8_SRILSUGsYdWmsdO";

export async function run(provider: NetworkProvider, args: string[]) {
    const ui = provider.ui();

    if (args.length === 0) {
        ui.write('Please provide a jetton address as an argument');
        return;
    }

    const poolCoreAddress = Address.parse(PoolCore_ADDRESS);
    const jettonAddress = args.length > 0 ? Address.parse(args[0]) : Address.parse(JETTON_ADDRESS);

    if (!poolCoreAddress || !jettonAddress) {
        ui.write('Invalid address format');
        return;
    }

    const poolCore = provider.open(PoolCore.fromAddress(poolCoreAddress));

    // Get pool info
    const poolInfo = await poolCore.getGetPoolInfo(jettonAddress);
    
    ui.write('\nPool Information:');
    ui.write(`Jetton Name: ${poolInfo.name}`);
    ui.write(`Symbol: ${poolInfo.symbol}`);
    ui.write(`Balance: ${poolInfo.balance} TON`);
    ui.write(`Holders Count: ${poolInfo.holdersCount}`);
    ui.write('\nVolume Information:');
    ui.write(`24h Volume: ${poolInfo.volume24h} TON`);
    ui.write(`6h Volume: ${poolInfo.volume6h} TON`);
    ui.write(`1h Volume: ${poolInfo.volume1h} TON`);
}
