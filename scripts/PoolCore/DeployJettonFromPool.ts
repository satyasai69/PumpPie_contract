import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { PoolCore } from '../../wrappers/PoolCore';
import { buildOnchainMetadata } from '../../utils/jetton-helpers';

export async function run(provider: NetworkProvider) {
    const PoolCore_ADDRESS = "kQBdg-8VF46WLikFviLfEMxKcrlfiCxgPg6JUYL6U-rFCsq7";
    
    try {
        // Initialize PoolCore contract instance
        const poolCore = provider.open(PoolCore.fromAddress(Address.parse(PoolCore_ADDRESS)));
        const senderAddress = provider.sender().address!;

        // Create content cell using jetton-helpers
        const content = buildOnchainMetadata({
            name: "Test Jetton",
            description: "Test Jetton for Pools",
            image: "https://www.example.com/image.png"
        });

        console.log('Sender address:', senderAddress.toString());
        console.log('Pool address:', PoolCore_ADDRESS);

        // Send deploy transaction
        console.log('Deploying new Jetton...');
        await poolCore.send(
            provider.sender(),
            {
                value: toNano('0.15'), // Increased gas value for deployment
            },
            {
                $$type: 'DeployJetton',
                owner: senderAddress,
                content: content,
                max_supply: toNano('1000000'), // 1 million max supply
                token_price: toNano('0.1'), // 0.1 TON initial price
                initial_mint: toNano('100000'), // Initial mint amount
                pool: Address.parse(PoolCore_ADDRESS)
            }
        );

        // Wait for deployment confirmation
        await provider.waitForDeploy(poolCore.address);

        console.log('Deploy message sent successfully');
        console.log('You can check the Pool at:');
        console.log(`https://testnet.tonscan.org/address/${PoolCore_ADDRESS}`);
    } catch (error) {
        console.error('Error in deployment:', error);
        throw error;
    }
}
