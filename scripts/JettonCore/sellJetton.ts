import { Address, toNano, fromNano } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';

export async function run(provider: NetworkProvider) {
    const JETTON_ADDRESS = "EQC2UOPy9_2SpzPXPxX8_-fI3eWS6f8O4wOmlegfz_trpB1x"; // Replace with your deployed JettonCore address
    const jettonAddress = Address.parse(JETTON_ADDRESS);

    try {
        console.log('Starting Jetton sale...');

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

        // Amount of tokens to sell (in smallest units)
        const sellAmount = toNano('1'); // Selling 1 token, adjust as needed
        const expectedTON = Number(fromNano(sellAmount)) * Number(fromNano(currentPrice));

        console.log(`\nSale Details:`);
        console.log(`Selling: ${fromNano(sellAmount)} tokens`);
        console.log(`Expected TON to receive: ~${expectedTON.toFixed(6)} TON`);
        console.log(`Gas fee: 0.2 TON`);

        // Send SellInCore message
        await jettonCore.send(
            provider.sender(),
            {
                value: toNano('0.2'), // Send enough TON for gas
            },
            {
                $$type: 'SellInCore',
                jettonAmount: sellAmount
            }
        );

        console.log(`\nSell request sent for ${fromNano(sellAmount)} tokens`);
        console.log('Note: TON will be received after burn confirmation');

    } catch (error) {
        console.error('Error during sale:', error);
    }
}
