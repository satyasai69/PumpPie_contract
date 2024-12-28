import { Address, toNano, fromNano } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';

export async function run(provider: NetworkProvider) {
    const JETTON_ADDRESS = "EQC2UOPy9_2SpzPXPxX8_-fI3eWS6f8O4wOmlegfz_trpB1x"; // Replace with your deployed JettonCore address
    const jettonAddress = Address.parse(JETTON_ADDRESS);

    try {
        console.log('Starting Jetton purchase...');

        // Open JettonCore contract
        const jettonCore = provider.open(JettonCore.fromAddress(jettonAddress));

        // Get current price and supply info
        const currentPrice = await jettonCore.getGetCurrentPrice();
        const totalSupply = await jettonCore.getGetTotalSupplyInCoins();
        const maxSupply = await jettonCore.getGetMaxSupply();

        console.log('Current Jetton Stats:');
        console.log(`Current Price: ${fromNano(currentPrice)} TON per token`);
        console.log(`Total Supply: ${fromNano(totalSupply)} tokens`);
        console.log(`Max Supply: ${fromNano(maxSupply)} tokens`);
        console.log(`Available to mint: ${fromNano(maxSupply - totalSupply)} tokens`);

        // Amount of TON to send for purchase (this will determine how many tokens you get)
        const purchaseAmount = toNano('0.5'); // Increased to 0.5 TON to ensure enough for purchase and gas
        
        // Calculate expected tokens (considering gas reserve)
        const gasReserve = toNano('0.06'); // Increased gas reserve to account for minting operation
        const actualPurchaseAmount = purchaseAmount - gasReserve;
        const expectedTokens = Number(fromNano(actualPurchaseAmount)) / Number(fromNano(currentPrice));
        
        console.log(`\nPurchase Details:`);
        console.log(`Sending: ${fromNano(purchaseAmount)} TON`);
        console.log(`Gas Reserve: ${fromNano(gasReserve)} TON`);
        console.log(`Actual Purchase Amount: ${fromNano(actualPurchaseAmount)} TON`);
        console.log(`Expected tokens to receive: ~${expectedTokens.toFixed(6)} tokens`);

        // Send "BuyInCore" message with TON
        await jettonCore.send(
            provider.sender(),
            {
                value: purchaseAmount,
            },
            "BuyInCore"
         /*   {
                $$type: 'BuyInCore',
                queryId: 0n
            } */
        );

        console.log(`\nPurchase request sent with ${fromNano(purchaseAmount)} TON`);

    } catch (error) {
        console.error('Error during purchase:', error);
    }
}
