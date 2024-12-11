import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Router } from '../build/Router/tact_Router';

export async function run(provider: NetworkProvider) {
    const FACTORY_ADDRESS = "EQBu1aYylFcWAeRnI2rVp7LU5wPBQ7QBvNOaDKtAIrjm1gHI"; // Replace with your factory address

    const router = provider.open(Router.createFromConfig({
        factory: Address.parse(FACTORY_ADDRESS),
        owner: provider.sender().address as Address
    }, provider.sender().address as Address));

    // Deploy contract
    await router.send(
        provider.sender(),
        {
            value: toNano('0.5)',
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(router.address);

    // Verify deployment
    console.log('Router deployed at:', router.address.toString());
    
    // Get and display factory address
    const factoryAddress = await router.getFactory();
    console.log('Factory address:', factoryAddress.toString());
}
