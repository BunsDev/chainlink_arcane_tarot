// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract ArcaneTarot is ERC721URIStorage, VRFConsumerBaseV2Plus {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
   string public constant MAJOR_ARCANA_URI = "ipfs://bafybeihrnhjv4ceqvltg3mygifiukety4suhzbd7q2givhbepucvl2xn2e/";
    string[22] private MAJOR_ARCANA_NAME = [
        "0 The Fool",
        "I The Magician",
        "II The High Priestess",
        "III The Empress",
        "IV The Emperor",
        "V The Hierophant",
        "VI The Lovers",
        "VII The Chariot",
        "VIII Strength",
        "IX The Hermit",
        "X The Wheel of Fortune",
        "XI Justice",
        "XII The Hanged Man",
        "XIII Death",
        "XIV Temperance",
        "XV The Devil",
        "XVI The Tower",
        "XVII The Star",
        "XVIII The Moon",
        "XIX The Sun",
        "XX Judgement",
        "XXI The World"
    ];

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    // Your subscription ID.
    uint256 public s_subscriptionId;

    // Past request IDs.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 public keyHash =
        0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 2;

    /**
     * HARDCODED FOR FUJI
     * COORDINATOR: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE
     */
    
    constructor(
        uint256 subscriptionId
    ) ERC721(
        "ArcaneTarot", "AT"
    ) VRFConsumerBaseV2Plus(0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE) { 
        s_subscriptionId = subscriptionId;
    }
    
    /////////////////////////
    //   ENTRY FUNCTIONS   //
    ////////////////////////
    // Assumes the subscription is funded sufficiently.
    // @param enableNativePayment: Set to `true` to enable payment in native tokens, or
    // `false` to pay in LINK
    function askQuestion(
        bool enableNativePayment
    ) external onlyOwner returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function drawCard(uint256 _requestId) public view returns (string memory){
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        uint256 card_index = request.randomWords[1]%22;
        string memory card = MAJOR_ARCANA_NAME[card_index];
        string memory position;
        if(request.randomWords[0]%2 == 0){
            position = "reverse";
        }else{
            position = "upright";
        }
        string memory card_uri = string(abi.encodePacked(MAJOR_ARCANA_URI, Strings.toString(card_index)));
        card_uri = string.concat(card_uri, ".png");
        string memory output = string.concat(card, "; ");
        output = string.concat(output, position);
        output = string.concat(output, "; ");
        output = string.concat(output, card_uri);
        return output;
    }
    
    function mintReading(address to, string memory tokenURI) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }
    
    ///////////////////////////////
    //   PUBLIC VIEW FUNCTIONS   //
    //////////////////////////////

    function getCurrentTokenId() public view returns (uint) {
        return _tokenIdCounter.current();
    }

    ///////////////////////////////
    //   HELPER FUNCTIONS   //
    //////////////////////////////

    function indexOf(string[] memory arr, string memory searchFor) pure private returns (int) {
        for (uint i = 0; i < arr.length; i++) {
            if (keccak256(abi.encodePacked(arr[i])) == keccak256(abi.encodePacked(searchFor))) {
            return int(i);
            }
        }
        return -1; // not found
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
