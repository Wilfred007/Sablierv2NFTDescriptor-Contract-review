
The Sablier Protocol
Sablier is a token distribution protocol developed with Ethereum
smart contracts, designed to facilitate by-the-second payments (streaming) for cryptocurrencies, specifically ERC-20 assets. The protocol employs a set of persistent and non-upgradable smart contracts that prioritize security, censorship resistance, self-custody, and functionality without the need for trusted intermediaries who may selectively restrict access.
Streaming
Asset streaming means the ability to make continuous, real-time payments on a per-second basis. This novel approach to making payments is the core concept of Sablier.
Let's take an example. Imagine Alice wants to stream 3,000 DAI to Bob during the whole month of January.
Alice deposits the 3,000 DAI in Sablier before Jan 1, setting the end time to Feb 1.
Bob's allocation of the DAI deposit increases every second beginning Jan 1.
On Jan 10, Bob will have earned approximately 1,000 DAI. He can send a transaction to Sablier to withdraw the tokens.
If at any point during January Alice wishes to get back her tokens, she can cancel the stream and recover what has not been streamed yet.
This streaming model is especially useful for use cases like vesting, payroll and airdrops.
NFTs
The Sablier Protocol wraps every stream in an ERC-721 non-fungible token (NFT), making the stream recipient the owner of the NFT. The recipient can transfer the NFT to another address, and this also transfers the right to withdraw funds from the stream, including any funds already streamed.




Contract Review

The SablierV2NFTDescriptor contract is a Solidity smart contract designed for generating metadata for NFTs associated with payment streams in the Sablier protocol.


IMPORTS

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
Function: This interface defines the metadata for ERC20 tokens, allowing contracts to query details like the token's name, symbol, and decimals. It extends the basic IERC20 interface by adding methods that provide additional information about the token.
Purpose: It enables compliance with the ERC20 standard while offering more functionality for tokens that wish to expose additional metadata.
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
Function: Similar to IERC20Metadata, this interface provides metadata functions for ERC721 tokens (non-fungible tokens). It allows for querying details such as the token's name and symbol.
Purpose: It ensures that NFT contracts adhere to the ERC721 standard while providing the necessary metadata to clients or other contracts.

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
Function: This utility library offers functions for encoding and decoding Base64 strings. It is commonly used for data representation, especially for assets like images or SVGs in a format suitable for storage or transfer.
Purpose: Base64 encoding is often used in NFTs to represent on-chain data (like images) in a compact form, allowing easier interaction with web applications.

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
Function: This library provides functions for string manipulation and conversion, such as converting integers to strings.
Purpose: It facilitates handling strings in the contract, which is crucial for generating readable outputs or combining strings for various purposes, like constructing metadata.

import { ISablierV2Lockup } from "./interfaces/ISablierV2Lockup.sol";
Function: This interface likely defines the methods for interacting with a lockup contract in the Sablier protocol, which allows for time-locked payments or vesting schedules.
Purpose: It provides a way for the main contract to interact with Sablier’s locking mechanisms, enabling functionalities such as distributing tokens over time or implementing vesting.

import { ISablierV2NFTDescriptor } from "./interfaces/ISablierV2NFTDescriptor.sol";
Function: This interface may define functions related to generating or retrieving the descriptive metadata of NFTs within the Sablier ecosystem.
Purpose: It allows the main contract to obtain or generate metadata for NFTs, which is essential for displaying information about them in user interfaces.

import { Lockup } from "./types/DataTypes.sol";
Function: This import likely refers to a custom type or struct defined in the DataTypes file, which may encapsulate information about lockups (e.g., beneficiary address, amount locked, unlock time).
Purpose: Using a struct improves code organization and readability, allowing developers to manage complex data types easily.

import { Errors } from "./libraries/Errors.sol";
Function: This library probably contains custom error definitions or revert messages that can be used throughout the contract to handle various error states gracefully.
Purpose: Centralizing error management helps maintain consistency in error handling and improves the readability of the contract by providing clear revert messages.

import { NFTSVG } from "./libraries/NFTSVG.sol";
Function: This library likely includes functions for generating SVG representations of NFTs, potentially allowing for dynamic or customizable visual outputs.
Purpose: It enables the contract to create or manipulate SVG images, which can be used directly in NFTs to represent their visual aspect on-chain.


import { SVGElements } from "./libraries/SVGElements.sol";
Function: This library may provide predefined SVG elements or utility functions to facilitate the creation of SVG images.
Purpose: It streamlines the process of constructing SVG graphics, making it easier to generate visually appealing NFTs.


struct TokenURIVars {
    address asset;
    string assetSymbol;
    uint128 depositedAmount;
    bool isTransferable;
    string json;
    bytes returnData;
    ISablierV2Lockup sablier;
    string sablierModel;
    string sablierStringified;
    string status;
    string svg;
    uint256 streamedPercentage;
    bool success;
}
This struct holds temporary variables used within the tokenURI function


function tokenURI(IERC721Metadata sablier, uint256 streamId) external view override returns (string memory uri) {
    	TokenURIVars memory vars;

    	// Load the contracts.
    	vars.sablier = ISablierV2Lockup(address(sablier));
    	vars.sablierModel = mapSymbol(sablier);
    	vars.sablierStringified = address(sablier).toHexString();
    	vars.asset = address(vars.sablier.getAsset(streamId));
    	vars.assetSymbol = safeAssetSymbol(vars.asset);
    	vars.depositedAmount = vars.sablier.getDepositedAmount(streamId);

    	// Load the stream's data.
    	vars.status = stringifyStatus(vars.sablier.statusOf(streamId));
    	vars.streamedPercentage = calculateStreamedPercentage({
        	streamedAmount: vars.sablier.streamedAmountOf(streamId),
        	depositedAmount: vars.depositedAmount
    	});

    	// Generate the SVG.
    	vars.svg = NFTSVG.generateSVG(
        	NFTSVG.SVGParams({
            	accentColor: generateAccentColor(address(sablier), streamId),
            	amount: abbreviateAmount({ amount: vars.depositedAmount, decimals: safeAssetDecimals(vars.asset) }),
            	assetAddress: vars.asset.toHexString(),
            	assetSymbol: vars.assetSymbol,
            	duration: calculateDurationInDays({
                	startTime: vars.sablier.getStartTime(streamId),
                	endTime: vars.sablier.getEndTime(streamId)
            	}),
            	sablierAddress: vars.sablierStringified,
            	progress: stringifyPercentage(vars.streamedPercentage),
            	progressNumerical: vars.streamedPercentage,
            	status: vars.status,
            	sablierModel: vars.sablierModel
        	})
    	);

    	// Performs a low-level call to handle older deployments that miss the `isTransferable` function.
    	(vars.success, vars.returnData) =
        	address(vars.sablier).staticcall(abi.encodeCall(ISablierV2Lockup.isTransferable, (streamId)));

    	// When the call has failed, the stream NFT is assumed to be transferable.
    	vars.isTransferable = vars.success ? abi.decode(vars.returnData, (bool)) : true;

    	// Generate the JSON metadata.
    	vars.json = string.concat(
        	'{"attributes":',
        	generateAttributes({
            	assetSymbol: vars.assetSymbol,
            	sender: vars.sablier.getSender(streamId).toHexString(),
            	status: vars.status
        	}),
        	',"description":"',
        	generateDescription({
            	sablierModel: vars.sablierModel,
            	assetSymbol: vars.assetSymbol,
            	sablierStringified: vars.sablierStringified,
            	assetAddress: vars.asset.toHexString(),
            	streamId: streamId.toString(),
            	isTransferable: vars.isTransferable
        	}),
        	'","external_url":"https://sablier.com","name":"',
        	generateName({ sablierModel: vars.sablierModel, streamId: streamId.toString() }),
        	'","image":"data:image/svg+xml;base64,',
        	Base64.encode(bytes(vars.svg)),
        	'"}'
    	);
    	// Encode the JSON metadata in Base64.
    	uri = string.concat("data:application/json;base64,", Base64.encode(bytes(vars.json)));
	}
TOKENURI():
The tokenURI function for an ERC721 token, specifically for use with Sablier V2 streaming contracts. The function generates metadata for the NFT associated with a Sablier streaming contract, which can be used to display information about the token, including visual elements (like SVG graphics) and JSON metadata, the function combines on-chain data from the Sablier streaming contract with dynamically generated SVG and JSON metadata, presenting a rich, interactive NFT representation of the token's stream status and asset details.
The vars.status calls an external function (stringifyStatus) to retrieve and format the stream’s current status (e.g., active, paused, completed).
The vars.streamedPercentage calculates the percentage of tokens that have already been streamed relative to the total deposit by calling the calculateStreamedPercentage function with the streamed and deposited amounts.
The NFTSVG.generateSVG function  constructs an SVG graphic to visually represent the token’s details, the function is called with parameters such as:
accentColor: A generated color based on the Sablier contract address and stream ID, giving a unique visual.
amount: An abbreviated representation of the deposited amount, taking into account the asset's decimal precision.
assetAddress and assetSymbol: Details of the asset, displayed in the SVG.
duration: Duration of the stream in days, calculated based on the stream’s start and end times.
sablierAddress: The Sablier contract address.
progress: The streamed percentage formatted as a string.
progressNumerical: The numeric percentage of streamed tokens.
status and sablierModel: Represent the stream’s status and model, respectively.

A low-level staticcall is performed on the Sablier contract to check if the stream is transferable by calling isTransferable. This ensures compatibility with older contracts that might lack this function.
If the call is successful, vars.isTransferable is set based on the result. If it fails, transferability defaults to true, assuming the token is transferable.


It builds a JSON metadata structure compatible with ERC721 metadata standards:
Attributes: JSON attributes generated via generateAttributes include details like the asset symbol, sender address, and stream status.
Description: A descriptive string generated by generateDescription, including model type, asset details, and stream ID.
External URL: Links to Sablier’s website.
Name: The token’s name is generated based on the model type and stream ID.
Image: The SVG graphic, encoded in Base64, is embedded directly into the metadata.
The JSON metadata string is Base64-encoded and prefixed with the MIME type for JSON (data:application/json;base64). This formatted URI is returned as tokenURI, which clients can use to fetch the token’s metadata.

  function abbreviateAmount(uint256 amount, uint256 decimals) internal pure returns (string memory) {
    	if (amount == 0) {
        	return "0";
    	}

    	uint256 truncatedAmount;
    	unchecked {
        	truncatedAmount = decimals == 0 ? amount : amount / 10 ** decimals;
    	}

    	// Return dummy values when the truncated amount is either very small or very big.
    	if (truncatedAmount < 1) {
        	return string.concat(SVGElements.SIGN_LT, " 1");
    	} else if (truncatedAmount >= 1e15) {
        	return string.concat(SVGElements.SIGN_GT, " 999.99T");
    	}

    	string[5] memory suffixes = ["", "K", "M", "B", "T"];
    	uint256 fractionalAmount;
    	uint256 suffixIndex = 0;

    	// Truncate repeatedly until the amount is less than 1000.
    	unchecked {
        	while (truncatedAmount >= 1000) {
            	fractionalAmount = (truncatedAmount / 10) % 100; // keep the first two digits after the decimal point
            	truncatedAmount /= 1000;
            	suffixIndex += 1;
        	}
    	}

    	// Concatenate the calculated parts to form the final string.
    	string memory prefix = string.concat(SVGElements.SIGN_GE, " ");
    	string memory wholePart = truncatedAmount.toString();
    	string memory fractionalPart = stringifyFractionalAmount(fractionalAmount);
    	return string.concat(prefix, wholePart, fractionalPart, suffixes[suffixIndex]);
	}

This function Converts large numerical amounts into a more readable format using suffixes (e.g., using "K" for thousands, "M" for millions). It does this by truncating the amount based on its size and appends the appropriate suffix, it also handles edge cases for very small or very large amounts by returning predefined strings.

It first checks If amount is zero, it immediately returns "0".
It calculates truncatedAmount, which is amount adjusted by decimals. This makes it compatible with different token decimal conventions (e.g., 18 decimals for ERC-20 tokens).
If decimals is 0, it simply assigns amount to truncatedAmount; otherwise, it divides amount by 10decimals10^{\text{decimals}}10decimals, effectively removing the fractional component.
If truncatedAmount is less than 1, it returns a string with "< 1" (indicating that the value is very small).
If truncatedAmount is very large (greater than or equal to 101510^{15}1015), it returns a capped value of "999.99T" (indicating that the value is extremely large).
It defines an array suffixes with common abbreviations ("K" for thousands, "M" for millions, etc.) to be used as suffixes.
It repeatedly divides truncatedAmount by 1000, moving up one position in the suffix array each time.
During each division, it calculates fractionalAmount, which captures the first two digits after the decimal point for the abbreviated amount.
wholePart stores the main part of truncatedAmount.
fractionalPart is constructed with the help of stringifyFractionalAmount, which turns fractionalAmount into a two-decimal-point string.
Finally, these parts are concatenated into a single output string with the appropriate suffix from the suffixes array.


  function calculateDurationInDays(uint256 startTime, uint256 endTime) internal pure returns (string memory) {
    	uint256 durationInDays;
    	unchecked {
        	durationInDays = (endTime - startTime) / 1 days;
    	}

    	// Return dummy values when the duration is either very small or very big.
    	if (durationInDays == 0) {
        	return string.concat(SVGElements.SIGN_LT, " 1 Day");
    	} else if (durationInDays > 9999) {
        	return string.concat(SVGElements.SIGN_GT, " 9999 Days");
    	}

    	string memory suffix = durationInDays == 1 ? " Day" : " Days";
    	return string.concat(durationInDays.toString(), suffix);
	}

The calculateDurationInDays function computes the duration between two timestamps (startTime and endTime) in days, returning a human-readable string that represents this duration. This is particularly useful for contracts that need to display time intervals in a way that’s easy for users to understand, such as lockup periods, loan durations, or membership timelines. 

It calculates the difference in days between endTime and startTime. The expression (endTime - startTime) / 1 days effectively converts the time difference from seconds (the unit used in Solidity timestamps) to days.
If the duration is less than one day (resulting in durationInDays == 0), it returns a formatted string "< 1 Day" to indicate that the duration is very short.
If the duration is extremely large (greater than 9,999 days), it returns a capped value "> 9999 Days" for clarity and to avoid overflow or display issues.
The function appends either " Day" or " Days" depending on whether durationInDays is exactly 1 or more than 1. This ensures correct grammar in the display, making the output more readable.
Returning the Final String:
The function returns a string combining the computed duration with the appropriate suffix, providing a clear, human-readable format like "5 Days" or "3 Days".


function calculateStreamedPercentage(
    	uint128 streamedAmount,
    	uint128 depositedAmount
	)
    	internal
    	pure
    	returns (uint256)
	{
    	// This cannot overflow because both inputs are uint128s, and zero deposit amounts are not allowed in Sablier.
    	unchecked {
        	return streamedAmount * 10_000 / depositedAmount;
    	}
	}

The calculateStreamedPercentage function calculates the percentage of a total deposited amount that has been streamed (or "spent") so far.
The function is a utility to compute streamed percentages with two decimal precision. It’s particularly useful in streaming-based payment or subscription systems where it’s important to know how much of a deposit has been used over time.
The function takes in two uint128 parameters: streamedAmount (the portion of funds that have been streamed so far) and depositedAmount (the total amount of funds initially deposited).
The goal is to compute the percentage of the depositedAmount that has been streamed.
The function returns the percentage of depositedAmount that streamedAmount represents. It multiplies streamedAmount by 10,000 and then divides by depositedAmount.
Multiplying by 10,000 allows the result to have two decimal points of precision. For example, a return value of 2500 represents 25.00%, and 10000 represents 100%.
The function uses unchecked to skip overflow checks, which is safe here because both streamedAmount and depositedAmount are uint128, and streamedAmount * 10_000 will not overflow within this data type. Additionally, it assumes that depositedAmount is non-zero, as specified by the comment that zero deposits aren’t allowed in Sablier.
It returns a uint256 representing the percentage of the total deposited amount that has been streamed. For example:
If streamedAmount is 5,000 and depositedAmount is 10,000, the function would return 5,000 * 10,000 / 10,000 = 5,0000 / 10,000 = 5000, meaning 50.00%.

  function generateAccentColor(address sablier, uint256 streamId) internal view returns (string memory) {
    	// The chain ID is part of the hash so that the generated color is different across chains.
    	uint256 chainId = block.chainid;

    	// Hash the parameters to generate a pseudo-random bit field, which will be used as entropy.
    	// | Hue 	| Saturation | Lightness | -> Roles
    	// | [31:16] | [15:8] 	| [7:0] 	| -> Bit positions
    	uint32 bitField = uint32(uint256(keccak256(abi.encodePacked(chainId, sablier, streamId))));

    	unchecked {
        	// The hue is a degree on a color wheel, so its range is [0, 360).
        	// Shifting 16 bits to the right means using the bits at positions [31:16].
        	uint256 hue = (bitField >> 16) % 360;

        	// The saturation is a percentage where 0% is grayscale and 100%, but here the range is bounded to [20,100]
        	// to make the colors more lively.
        	// Shifting 8 bits to the right and applying an 8-bit mask means using the bits at positions [15:8].
        	uint256 saturation = ((bitField >> 8) & 0xFF) % 80 + 20;

        	// The lightness is typically a percentage between 0% (black) and 100% (white), but here the range
        	// is bounded to [30,100] to avoid dark colors.
        	// Applying an 8-bit mask means using the bits at positions [7:0].
        	uint256 lightness = (bitField & 0xFF) % 70 + 30;

        	// Finally, concatenate the HSL values to form an SVG color string.
        	return string.concat("hsl(", hue.toString(), ",", saturation.toString(), "%,", lightness.toString(), "%)");
    	}
	}



The generateAccentColor function generates a unique color in HSL format based on the combination of the current blockchain network, a sablier address, and a streamId. It does this by hashing these values and using the hash as a source of pseudo-randomness to derive the hue, saturation, and lightness of the color.

 function generateAttributes(
    	string memory assetSymbol,
    	string memory sender,
    	string memory status
	)
    	internal
    	pure
    	returns (string memory)
	{
    	return string.concat(
        	'[{"trait_type":"Asset","value":"',
        	assetSymbol,
        	'"},{"trait_type":"Sender","value":"',
        	sender,
        	'"},{"trait_type":"Status","value":"',
        	status,
        	'"}]'
    	);
	}

The generateAttributes function generates a JSON-formatted string representing attributes for an asset, sender, and status. This type of structured metadata is often used in NFTs or other digital assets to define their properties in a standardized way.
This JSON format is useful in NFT standards such as ERC-721 or ERC-1155, where generateAttributes can create metadata that represents specific traits of a digital asset, providing a structured way to include descriptive information about the asset.

function generateDescription(
    	string memory sablierModel,
    	string memory assetSymbol,
    	string memory sablierStringified,
    	string memory assetAddress,
    	string memory streamId,
    	bool isTransferable
	)
    	internal
    	pure
    	returns (string memory)
	{
    	// Depending on the transferability of the NFT, declare the relevant information.
    	string memory info = isTransferable
        	?
        	unicode"⚠️ WARNING: Transferring the NFT makes the new owner the recipient of the stream. The funds are not automatically withdrawn for the previous recipient."
        	: unicode"❕INFO: This NFT is non-transferable. It cannot be sold or transferred to another account.";

    	return string.concat(
        	"This NFT represents a payment stream in a Sablier V2 ",
        	sablierModel,
        	" contract. The owner of this NFT can withdraw the streamed assets, which are denominated in ",
        	assetSymbol,
        	".\\n\\n- Stream ID: ",
        	streamId,
        	"\\n- ",
        	sablierModel,
        	" Address: ",
        	sablierStringified,
        	"\\n- ",
        	assetSymbol,
        	" Address: ",
        	assetAddress,
        	"\\n\\n",
        	info
    	);
	}
The generateDescription function creates a detailed description for an NFT associated with a payment stream in a Sablier V2 contract. This description includes information about the payment stream and whether the NFT can be transferred to another owner. It returns a string with structured information about the stream and a warning or info message based on the transferability of the NFT.
This function is useful for generating a standardized and informative description for NFTs representing payment streams. The description provides the owner or potential buyers with crucial information about the NFT’s purpose, associated contract, and transferability details. This is especially helpful for users interacting with Sablier's streaming payments in a decentralized finance (DeFi) context.


function isAllowedCharacter(string memory str) internal pure returns (bool) {
    	// Convert the string to bytes to iterate over its characters.
    	bytes memory b = bytes(str);

    	uint256 length = b.length;
    	for (uint256 i = 0; i < length; ++i) {
        	bytes1 char = b[i];

        	// Check if it's a space, dash, or an alphanumeric character.
        	bool isSpace = char == 0x20; // space
        	bool isDash = char == 0x2D; // dash
        	bool isDigit = char >= 0x30 && char <= 0x39; // 0-9
        	bool isUppercaseLetter = char >= 0x41 && char <= 0x5A; // A-Z
        	bool isLowercaseLetter = char >= 0x61 && char <= 0x7A; // a-z
        	if (!(isSpace || isDash || isDigit || isUppercaseLetter || isLowercaseLetter)) {
            	return false;
        	}
    	}
    	return true;
	}

The isAllowedCharacter function checks whether all characters in a given string are allowed, meaning they must be either a space, a dash, or an alphanumeric character (0–9, A–Z, a–z). If any character in the string does not meet these conditions, the function returns false. Otherwise, it returns true.
This function is useful for validating input strings, ensuring they contain only specific characters. It's especially relevant in applications where sanitized input is essential, such as user-generated content or naming conventions for tokens or identifiers.

function mapSymbol(IERC721Metadata sablier) internal view returns (string memory) {
    	string memory symbol = sablier.symbol();
    	if (symbol.equal("SAB-V2-LOCKUP-LIN")) {
        	return "Lockup Linear";
    	} else if (symbol.equal("SAB-V2-LOCKUP-DYN")) {
        	return "Lockup Dynamic";
    	} else if (symbol.equal("SAB-V2-LOCKUP-TRA")) {
        	return "Lockup Tranched";
    	} else {
        	revert Errors.SablierV2NFTDescriptor_UnknownNFT(sablier, symbol);
    	}
	}
The mapSymbol function takes an ERC-721 token contract (sablier) as input and maps its symbol to a human-readable description. It does this by calling the symbol() function of the IERC721Metadata contract and checking the returned value against predefined symbols. If the symbol matches a known value, it returns the corresponding description; otherwise, it reverts with an error.
This function is used to translate technical token symbols into user-friendly descriptions for display. It ensures that only recognized symbols are processed, providing a safeguard against unexpected symbols by reverting if an unknown symbol is encountered.

 function safeAssetDecimals(address asset) internal view returns (uint8) {
    	(bool success, bytes memory returnData) = asset.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
    	if (success && returnData.length == 32) {
        	return abi.decode(returnData, (uint8));
    	} else {
        	return 0;
    	}
	}
The safeAssetDecimals function attempts to retrieve the decimal count of an ERC-20 token (specified by its asset address) in a safe way. If successful, it returns the token's number of decimals. If the call fails or the returned data is not as expected, it defaults to returning 0.
This function is helpful when interacting with tokens that may or may not be fully compliant with the ERC-20 standard. By using a fallback value of 0 when the call fails, it avoids contract errors or reverts when dealing with assets that lack a decimals function. This makes it safer and more flexible for managing tokens across various implementations.

function safeAssetSymbol(address asset) internal view returns (string memory) {
    	(bool success, bytes memory returnData) = asset.staticcall(abi.encodeCall(IERC20Metadata.symbol, ()));

    	// Non-empty strings have a length greater than 64, and bytes32 has length 32.
    	if (!success || returnData.length <= 64) {
        	return "ERC20";
    	}

    	string memory symbol = abi.decode(returnData, (string));

    	// Check if the symbol is too long or contains disallowed characters. This measure helps mitigate potential
    	// security threats from malicious assets injecting scripts in the symbol string.
    	if (bytes(symbol).length > 30) {
        	return "Long Symbol";
    	} else {
        	if (!isAllowedCharacter(symbol)) {
            	return "Unsupported Symbol";
        	}
        	return symbol;
    	}
	}
The safeAssetSymbol function retrieves the symbol of an ERC-20 token identified by its asset address while implementing safety checks to ensure that the symbol is valid and free from potential security threats.
This function is particularly useful for applications that need to interact with a variety of ERC-20 tokens, as it ensures that the symbol retrieved is not only accurate but also safe to use. By implementing these checks, the function helps mitigate potential security risks, such as malicious tokens attempting to inject harmful scripts through their symbol strings.

 function stringifyFractionalAmount(uint256 fractionalAmount) internal pure returns (string memory) {
    	// Return the empty string if the fractional amount is zero.
    	if (fractionalAmount == 0) {
        	return "";
    	}
    	// Add a leading zero if the fractional part is less than 10, e.g. for "1", this function returns ".01%".
    	else if (fractionalAmount < 10) {
        	return string.concat(".0", fractionalAmount.toString());
    	}
    	// Otherwise, stringify the fractional amount simply.
    	else {
        	return string.concat(".", fractionalAmount.toString());
    	}
	}
The stringifyFractionalAmount function is a utility that converts a given fractional amount (represented as a uint256) into a formatted string suitable for display, specifically for cases where the amount represents a fractional part of a number (such as a percentage).
This function is particularly useful in scenarios where fractional values need to be displayed, such as in financial applications or user interfaces that deal with monetary amounts or percentages. By ensuring consistent formatting of the fractional component, it helps maintain clarity and readability in the presentation of numerical data.

 function stringifyPercentage(uint256 percentage) internal pure returns (string memory) {
    	// Extract the last two decimals.
    	string memory fractionalPart = stringifyFractionalAmount(percentage % 100);

    	// Remove the last two decimals.
    	string memory wholePart = (percentage / 100).toString();

    	// Concatenate the whole and fractional parts.
    	return string.concat(wholePart, fractionalPart, "%");
	}

The stringifyPercentage function converts a given percentage (represented as a uint256) into a formatted string that appends a percent sign (%) to the end. This function effectively separates the whole number part of the percentage from its fractional component, ensuring proper formatting for display.
This function is used to calculate  percentages need to be displayed in a user-friendly manner, especially when dealing with financial data, statistics, or any context where precision is key. By formatting the percentage correctly, it enhances readability and user experience.

function stringifyStatus(Lockup.Status status) internal pure returns (string memory) {
    	if (status == Lockup.Status.DEPLETED) {
        	return "Depleted";
    	} else if (status == Lockup.Status.CANCELED) {
        	return "Canceled";
    	} else if (status == Lockup.Status.STREAMING) {
        	return "Streaming";
    	} else if (status == Lockup.Status.SETTLED) {
        	return "Settled";
    	} else {
        	return "Pending";
    	}
	}

The stringifyStatus function is designed to convert a Lockup.Status enumeration into a human-readable string representation of the status.















