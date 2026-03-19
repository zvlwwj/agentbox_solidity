// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/AgentboxStorage.sol";
import "../storage/LibDiamond.sol";

contract AgentboxDiamond {
    event DiamondCut(FacetCut[] _diamondCut);

    enum FacetCutAction {Add, Replace, Remove}

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    modifier onlyOwner() {
        require(msg.sender == AgentboxStorage.getStorage().owner, "Not owner");
        _;
    }

    constructor() {
        AgentboxStorage.getStorage().owner = msg.sender;
    }

    function diamondCut(FacetCut[] calldata _diamondCut) external onlyOwner {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        for (uint256 i = 0; i < _diamondCut.length; i++) {
            FacetCut memory cut = _diamondCut[i];
            address facetAddress = cut.facetAddress;
            for (uint256 j = 0; j < cut.functionSelectors.length; j++) {
                bytes4 selector = cut.functionSelectors[j];
                
                if (cut.action == FacetCutAction.Add || cut.action == FacetCutAction.Replace) {
                    require(facetAddress != address(0), "Facet cannot be zero");
                    address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;

                    if (cut.action == FacetCutAction.Add) {
                        require(oldFacetAddress == address(0), "Selector already exists");
                    }

                    if (cut.action == FacetCutAction.Replace) {
                        require(oldFacetAddress != address(0), "Selector not found");
                        require(oldFacetAddress != facetAddress, "Replace facet matches old");
                        _removeSelector(ds, oldFacetAddress, selector);
                    }
                    
                    if (ds.facetFunctionSelectors[facetAddress].functionSelectors.length == 0) {
                        ds.facetFunctionSelectors[facetAddress].facetAddressPosition = ds.facetAddresses.length;
                        ds.facetAddresses.push(facetAddress);
                    }
                    
                    ds.selectorToFacetAndPosition[selector] = LibDiamond.FacetAddressAndPosition(
                        facetAddress,
                        uint96(ds.facetFunctionSelectors[facetAddress].functionSelectors.length)
                    );
                    ds.facetFunctionSelectors[facetAddress].functionSelectors.push(selector);
                    
                } else if (cut.action == FacetCutAction.Remove) {
                    address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
                    require(oldFacetAddress != address(0), "Selector not found");
                    _removeSelector(ds, oldFacetAddress, selector);
                    delete ds.selectorToFacetAndPosition[selector];
                }
            }
        }
        emit DiamondCut(_diamondCut);
    }
    
    function _removeSelector(LibDiamond.DiamondStorage storage ds, address facetAddress, bytes4 selector) internal {
        uint96 selectorPosition = ds.selectorToFacetAndPosition[selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[facetAddress].functionSelectors.length - 1;
        
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = selectorPosition;
        }
        
        ds.facetFunctionSelectors[facetAddress].functionSelectors.pop();
        
        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[facetAddress].facetAddressPosition;
        }
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
