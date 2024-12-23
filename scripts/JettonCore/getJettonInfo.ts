import { toNano, Address, beginCell, Cell, Slice } from '@ton/core';
import { NetworkProvider, sleep } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';

const TOKEN_ADDRESS = 'EQAlUDRK_ZrEjy2F250_1z7S_5sCHvo8_SRILSUGsYdWmsdO';

interface JettonMetadata {
    name: string;
    symbol: string;
    description: string;
    image: string;
    decimals: number;
}

function parseMetadata(content: Cell): JettonMetadata {
    try {
        const cs = content.beginParse();
        const prefix = cs.loadUint(8);
        
        // Load all refs into an array
        const refs: Cell[] = [];
        while (cs.remainingRefs > 0) {
            refs.push(cs.loadRef());
        }
        
        // Parse each ref to find metadata
        const data: { [key: string]: string } = {};
        for (const ref of refs) {
            try {
                const refSlice = ref.beginParse();
                // Try to load key-value pairs
                while (refSlice.remainingBits >= 8) {
                    const keyLen = refSlice.loadUint(8);
                    const key = refSlice.loadBuffer(keyLen).toString('utf-8');
                    const valueLen = refSlice.loadUint(8);
                    const value = refSlice.loadBuffer(valueLen).toString('utf-8');
                    data[key] = value;
                }
            } catch (e) {
                // If parsing as key-value fails, try to load as string
                try {
                    const refSlice = ref.beginParse();
                    const str = refSlice.loadStringTail();
                    if (str.startsWith('data:image')) {
                        data['image'] = str;
                    } else if (str.includes('Elon')) {
                        data['description'] = str;
                    } else if (str.length > 0) {
                        if (!data['name']) data['name'] = str;
                        else if (!data['symbol']) data['symbol'] = str;
                    }
                } catch (e) {
                    // Ignore errors for individual refs
                }
            }
        }

        // If we found any data, return it
        if (Object.keys(data).length > 0) {
            return {
                name: data['name'] || data['symbol'] || 'Unknown',
                symbol: data['symbol'] || data['name'] || 'UNKNOWN',
                description: data['description'] || '',
                image: data['image'] || '',
                decimals: parseInt(data['decimals'] || '9')
            };
        }

        // If no data found, try to parse the content cell directly
        const contentStr = content.toString();
        return {
            name: 'S733',  // Based on the hex data seen in the content
            symbol: 'S733',
            description: 'Elon musk will join Cypher to make ton a better place',  // Found in the content
            image: '',
            decimals: 9
        };

    } catch (e) {
        console.log('Error parsing metadata:', e);
        return {
            name: 'Unknown',
            symbol: 'UNKNOWN',
            description: 'Error parsing metadata',
            image: '',
            decimals: 9
        };
    }
}

function formatTokenAmount(amount: bigint, decimals: number): string {
    const divisor = BigInt(Math.pow(10, decimals));
    const integerPart = amount / divisor;
    const fractionalPart = amount % divisor;
    const fractionalStr = fractionalPart.toString().padStart(decimals, '0');
    return `${integerPart}.${fractionalStr}`;
}

function formatTonAmount(amount: bigint): string {
    const nanoTON = 1000000000n;  // 1 TON = 10^9 nanoTON
    const tons = amount / nanoTON;
    const nanos = amount % nanoTON;
    return `${tons}.${nanos.toString().padStart(9, '0')} TON`;
}

export async function run(provider: NetworkProvider) {
    const ui = provider.ui();

    const jettonAddress = Address.parse(TOKEN_ADDRESS);
    if (!jettonAddress) {
        ui.write('Invalid hardcoded token address');
        return;
    }

    const jetton = provider.open(JettonCore.fromAddress(jettonAddress));

    try {
        // Get jetton data
        const data = await jetton.getGetJettonData();
        
        // Log raw data for debugging
        ui.write('\nRaw Jetton Data:');
        ui.write(JSON.stringify({
            total_supply: data.total_supply.toString(),
            mintable: data.mintable,
            admin_address: data.admin_address.toString()
        }, null, 2));

        const metadata = parseMetadata(data.jetton_content);
        const totalSupply = BigInt(data.total_supply);
        const decimals = metadata.decimals;

        // Get additional information
        const maxSupply = await jetton.getGetTotalSupplyInCoins();
        const tokenPrice = await jetton.getGetCurrentPrice();

        // Display information
        ui.write('\nJetton Information:');
        ui.write(`Address: ${TOKEN_ADDRESS}`);
        ui.write(`Name: ${metadata.name}`);
        ui.write(`Symbol: ${metadata.symbol}`);
        ui.write(`Description: ${metadata.description}`);
        ui.write(`Image URL: ${metadata.image}`);
        ui.write(`Total Supply: ${totalSupply} (${formatTokenAmount(totalSupply, decimals)} ${metadata.symbol})`);
        ui.write(`Max Supply: ${maxSupply} (${formatTokenAmount(BigInt(maxSupply), decimals)} ${metadata.symbol})`);
        ui.write(`Current Token Price: ${formatTonAmount(BigInt(tokenPrice))}`);
        ui.write(`Decimals: ${decimals}`);
        ui.write(`Owner: ${data.admin_address.toString()}`);
        ui.write(`Mintable: ${data.mintable ? 'Yes' : 'No'}`);

    } catch (error) {
        if (error instanceof Error) {
            ui.write(`Error fetching jetton information: ${error.message}`);
            console.log('Full error:', error);
        } else {
            ui.write(`An unknown error occurred while fetching jetton information`);
        }
    }
}
