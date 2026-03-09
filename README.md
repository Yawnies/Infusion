# Infusion
This addon allows you to track two specific druid spells: Innervate and Rebirth (commonly known as brez/battle rez/etc). Whenever someone in your raid uses them, it'll display the cooldowns for these spells so that you can work your gameplay around their availability, such as requesting them during boss/trash segments where you run out of mana often.  
Particularly useful for priests due to their high mana costs and for raid leaders looking to track these cooldowns for ease of callouts.  
**INFUSION REQUIRES SUPERWOW TO WORK!**
## Interface & Commands
Usage is as simple as it gets. Make sure to join a raid group before using it!  
To access the menu, click the innervate button on your minimap wheel, or type `/infusion` on your chat bar:  
  
![Menu](https://files.catbox.moe/dfatbq.png)  
  
The **Scan** button will scan the raid for all the druids, then display the tracking widgets you have selected (for tracking innervates, brez, or both at once) if there are any in the raid. The **Help** button displays the available commands.  
Clicking any of the druid names in the widgets will automatically whisper them requesting an Innervate for you. (Innervate only, does not work on the Rebirth widget)  
![TrackersBig](https://files.catbox.moe/2p0plb.png) ![TrackersSmol](https://files.catbox.moe/185uiy.png)  
Above is a comparison between the default and the 'Compact' widgets. Both have the same functionality.
### Commands
`/infusion`: opens/closes the main menu.  
`/infusionscan` or `/infs`: scans the raid and activates the widgets without having to open the menu.  
`/infusionclose` or `/infc`: closes the tracking widgets. **Be aware that doing this will require a full scan again, which in turn resets any ongoing cooldown counters!**
## Tips/Caveats
* Use this when you're about to first pull or a few minutes before so you can be sure every druid is tracked properly/everyone is in the raid. Don't use it mid raid or you will miss druid CDs if they happened to use them before.
* If you disconnect or leave mid raid, the cooldowns **will reset** and you'll have to scan again. This is unavoidable.
## Contributions
Welcome contributions of any kind, particularly those related to optimization. This was coded using Codex magic and a healthy dose of reviewing, but I'm nowhere near an expert in archaic 2004 Lua and can only do so much. If you read through and spot silly things that could be improved, let me know!
