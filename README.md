# 🎮 remote-df - Play Dwarf Fortress in your browser

[![](https://img.shields.io/badge/Download-remote--df-blue.svg)](https://github.com/Tabitha4937/remote-df)

remote-df allows you to run Dwarf Fortress on a computer and see the game feed inside a web browser. You can play your games from any device connected to your network.

## ⚙️ System Requirements

Your computer needs to meet these basic standards to run the software.

*   Windows 10 or Windows 11.
*   A modern web browser like Chrome, Firefox, or Edge.
*   At least 4GB of RAM.
*   A stable internet connection for your home network.

## 💾 How to Install

Follow these steps to set up the software on your machine.

1. Go to the [official release page](https://github.com/Tabitha4937/remote-df).
2. Look for the latest version under the "Releases" section.
3. Download the file named `remote-df-setup.exe`.
4. Run the file after the download finishes.
5. Follow the prompts on your screen to complete the installation.

The installation process stores the files in a folder on your local drive. You can choose a location that works for you.

## 🚀 Getting Started

Once the installation ends, you can start the application.

1. Open the remote-df application from your desktop shortcut or the Start menu.
2. A window will appear. This window keeps the connection to the game active. Keep this window open while you play.
3. Open your web browser once the application shows the status as "Ready."
4. Type `localhost:8080` into the address bar at the top of your browser.
5. Press Enter to load the game screen.

The game will now display inside your browser window. You can interact with the game menus using your mouse and keyboard just as you would with the standard desktop version.

## 🛠 Troubleshooting Common Issues

Problems may occur during your first setup. Check this list if the game fails to load.

### The browser shows an error
If the page does not load, restart the remote-df application. Wait ten seconds before you refresh the browser page. Ensure no other programs use the 8080 port on your computer.

### The game runs slowly
Dwarf Fortress requires significant memory. Close other programs such as web browsers with many tabs or video streaming software to free up system memory.

### You cannot connect from another device
If you want to play on a tablet or a laptop on the same network, you must find the IP address of your main computer. 
1. Open the Command Prompt on the main computer by typing `cmd` in the search bar.
2. Type `ipconfig` and press Enter.
3. Locate the number next to IPv4 Address. It usually looks like `192.168.1.XX`.
4. Type that number into the web browser of your secondary device, followed by `:8080`. 
Example: `192.168.1.15:8080`

## 🛡 Security and Privacy

The application runs locally on your machine. No data leaves your home network. Your game sessions remain private. Use a strong password if you enable remote access features in the settings menu, as this prevents unauthorized people on your network from accessing your game.

## 🔧 Advanced Configuration

You can change how the server behaves through the configuration file inside the installation folder. Open `config.json` with any text editor to modify settings.

*   **port**: Change the number if 8080 conflicts with other software.
*   **max_clients**: Set the number of allowed connections.
*   **graphics_mode**: Toggle between simple text view and graphical tile sets to improve performance.

Always restart the application after you save changes to the configuration file. 

## 📋 Frequently Asked Questions

**Does this software modify my game files?**
No, remote-df treats your game files as read-only. Your original Dwarf Fortress installation remains safe.

**Can I save my progress?**
Yes. You use the in-game menu to save your progress. The game data saves to your computer folders exactly as it does when you play without this tool.

**Do I need a high-speed internet connection?**
A fast internet connection is only necessary if you intend to play from outside your home network. For home use, your local Wi-Fi or wired connection is sufficient.

**Is this official software?**
This is a community-made tool created for convenience. It does not replace the base game. You must own a copy of Dwarf Fortress for this tool to function.

## 📜 License Information

This software uses an open-source license. You can view the full license terms in the file labeled `LICENSE` inside the project folder. You may use this software without charge for personal, non-commercial purposes. 

## 🤝 Getting More Help

If you run into issues, check the issues tab on the repository page. Users often share solutions for common setup errors there. Check if someone else reported your issue before you start a new thread. Provide your Windows version and the specific error message to help others identify the problem. Clean communication ensures you get a response faster from the community.