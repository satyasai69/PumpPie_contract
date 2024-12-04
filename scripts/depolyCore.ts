import { toNano } from '@ton/core';
import { Core } from '../wrappers/core';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const core = provider.open(await Core.fromInit());

    await core.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n
        }
    );

    await provider.waitForDeploy(core.address);

    console.log('Core deployed at:', core.address);
}