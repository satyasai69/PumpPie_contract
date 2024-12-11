
import { Address, toNano, beginCell } from '@ton/core';
import { PoolCore } from '../../wrappers/PoolCore';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) { 




    const sampleJetton = provider.open(await PoolCore.fromInit()); //1000000000000000000n

    await sampleJetton.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n
        }
       
    );

    await provider.waitForDeploy(sampleJetton.address);

    // run methods on `sampleJetton`
} 
