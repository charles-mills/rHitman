# rHitman - Contract Management System for Garry's Mod

A hitman contract management system for Garry's Mod DarkRP servers, featuring a custom, user-friendly UI and robust contract handling. A comprehensive configuration system is provided to customize the addon to your server's needs - including price ranges, contract duration, and maximum active contracts per player.

## Features

- **Modern User Interface**
  - A fully custom UI, designed to be efficient and easy-to-use
  - Custom animated components
  - Responsive design and smooth animations
  - User-friendly error messages

- **Contract Management**
  - Create and manage hitman contracts
  - Dynamic player targeting system
  - Automatic contract expiration
  - Contract status tracking (active, completed, failed, cancelled)

- **Advanced Configuration**
  - Customizable price ranges
  - Configurable currency symbol
  - Adjustable contract duration
  - Maximum active contracts limit

- **TODO**
  - Random contracts.
  - Full implementation of the custom UI.
  - Custom notification system.
  - Victim marker whilst ADS to allow for sniper hits without accidentally killing the wrong person.
  - Contract evidence collection (optional feature).
  - Contract victims last known area (optional feature, with configuration required - will be useful for multi-layered maps where a distance calculation isn't always helpful).

## Configuration

Key configuration options in `lua/rhitman/config/sh_config.lua`:

```lua
-- Price Limits
MinimumHitPrice = 1000        -- Minimum contract price
MaximumHitPrice = 1000000     -- Maximum contract price

-- Contract Settings
MaxActiveContractsPerContractor = 1  -- Maximum active contracts per player
ContractDuration = 3600             -- Contract duration in seconds (1 hour)

-- Display Settings
CurrencySymbol = "$"               -- Currency symbol for price display
```

## Installation

1. Download the addon
2. Place it in your server's `garrysmod/addons` directory
3. Configure settings in `lua/rhitman/config/sh_config.lua`
4. Restart your server

## Dependencies

- Garry's Mod
- DarkRP Gamemode

## Usage

### Creating a Contract
1. Create a contract using a supported hit command (!hits, !rhits /rhits, /hits)
2. Navigate to the contract creation menu
2. Select a target player from the dropdown
3. Enter the contract reward amount
4. Confirm contract creation

### Managing Contracts
1. View active contracts using a supported hit command (!hits, !rhits /rhits, /hits)
2. Accept contracts as a hitman
3. Track contract status and completion

## UI Preview (Beta - Subject to Change)
![image](https://github.com/user-attachments/assets/04c46e64-1548-4203-8cd2-ebeb0fbea686)
![image](https://github.com/user-attachments/assets/ce5e9190-9e29-4345-a446-99d497c39366)

## License

This project is licensed under the MIT License - see LICENSE for details.

## Support

For issues, bug reports, or feature requests, please create an issue in the repository.
