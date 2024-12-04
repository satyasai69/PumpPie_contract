import { toNano } from '@ton/core';
import { Factory } from '../wrappers/Factory';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const factory = provider.open(await Factory.fromInit());

    // Deploy Factory contract
    await factory.send(
        provider.sender(),
        {
            value: toNano('0.5'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(factory.address);
    console.log('Factory deployed at:', factory.address);
    
    // Save this address to use in CreatePool.ts
}