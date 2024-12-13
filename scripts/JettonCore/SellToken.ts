import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';

export async function run(provider: NetworkProvider) {
    const TOKEN_ADDRESS = 'EQBWNd8tsYQa4QgQM2qj2YRsdc-h-_jp9KBRW6KBnYLLHo9P';
    const TOKENS_TO_SELL = 1_000_000_000n; // 1 token in nano-units
    
    try {
        // Initialize JettonCore contract instance
        const jettonCore = provider.open(JettonCore.fromAddress(Address.parse(TOKEN_ADDRESS)));
        
        // Get current price before selling
        const preBurnPrice = await jettonCore.getGetCurrentPrice();
        console.log('Current Token Price:', preBurnPrice.toString());
        console.log('Price in TON:', (Number(preBurnPrice) / 1_000_000_000).toFixed(6));

        // Get total supply before selling
        const preBurnSupply = await jettonCore.getGetTotalSupplyInCoins();
        console.log('Total Supply before selling:', preBurnSupply.toString(), 'coins');

        // Calculate expected TON return based on current price
        const expectedTonReturn = (BigInt(TOKENS_TO_SELL) * preBurnPrice) / 1_000_000_000n;
        console.log('Expected TON return:', (Number(expectedTonReturn) / 1_000_000_000).toFixed(6), 'TON');

        // Send the "SellTokens" transaction
        await jettonCore.send(
            provider.sender(),
            {
                value: toNano('0.1'), // Gas fees
            },
            {
                $$type: 'SellTokens',
                tokenAmount: TOKENS_TO_SELL
            }
        );

        console.log(`SellTokens transaction sent successfully for ${(Number(TOKENS_TO_SELL) / 1_000_000_000).toFixed(9)} tokens`);

        // Wait a bit for the transaction to be processed
        await provider.waitForDeploy(jettonCore.address);

        // Get new price after selling
        const postBurnPrice = await jettonCore.getGetCurrentPrice();
        console.log('\nToken Price after selling:', postBurnPrice.toString());
        console.log('Price in TON:', (Number(postBurnPrice) / 1_000_000_000).toFixed(6));

        // Get new total supply after selling
        const postBurnSupply = await jettonCore.getGetTotalSupplyInCoins();
        console.log('Total Supply after selling:', postBurnSupply.toString(), 'coins');
        
        // Calculate actual price change
        const priceChange = ((Number(postBurnPrice) - Number(preBurnPrice)) / 1_000_000_000).toFixed(6);
        console.log('Price change:', priceChange, 'TON');
        
        console.log('\nYou can check the transaction at:');
        console.log(`https://testnet.tonscan.org/address/${TOKEN_ADDRESS}`);
        
    } catch (error) {
        console.error('Error selling tokens:', error);
        throw error;
    }
}
