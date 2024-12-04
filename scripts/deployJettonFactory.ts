import { Address, toNano } from '@ton/core';
import { JettonFactory } from '../wrappers/JettonFactory';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const owner = provider.sender().address!;
    
    // Deploy JettonFactory
    const factory = JettonFactory.createFromConfig({
        owner: owner
    }, code);

    await factory.sendDeploy(provider.sender(), toNano('0.05'));
    
    console.log('JettonFactory deployed at:', factory.address);
    
    return factory;
}

// Function to deploy a new Jetton using the factory
export async function deployJettonWithFactory(
    provider: NetworkProvider,
    factory: JettonFactory,
    params: {
        name: string;
        symbol: string;
        description: string;
        image: string;
        totalSupply: string;
        adminAddress: string;
    }
) {
    const deployParams = {
        params: {
            name: params.name,
            symbol: params.symbol,
            description: params.description,
            image: params.image,
            totalSupply: toNano(params.totalSupply),
            adminAddress: Address.parse(params.adminAddress)
        }
    };
    
    await factory.sendDeployJetton(provider.sender(), {
        value: toNano('0.5'),
        params: deployParams
    });
    
    console.log('Deployment message sent to factory');
}
