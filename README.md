# Infusion
This addon allows you to track the cooldowns of two specific druid spells: Innervate and Rebirth (commonly known as brez/battle rez/etc). Whenever a druid in your raid uses them, it'll display their cooldowns so that you can work your gameplay around their availability, as well as requesting them with a simple click on your ~mana slave~ druid of choice during boss/trash segments where you run out of mana often.  
  
Particularly useful for priests due to their high mana costs and for raid leaders looking to track these cooldowns for ease of callouts.  
  
**INFUSION REQUIRES SUPERWOW TO WORK!**
## Interface & Commands
Usage is as simple as it gets. Join a raid group and the tracker widgets will display automatically, even if you reload or restart the game while inside a raid group.  
To access the menu, click the innervate button on your minimap wheel, or type `/infusion` on your chat bar:  
  
![Menu](https://files.catbox.moe/5n1zkw.png)  
  
The **Help** button displays the available commands.  
**Clicking** any of the druid names in the widgets will automatically whisper them requesting an Innervate for you. (Innervate only, does not work on the Rebirth widget)  
  
![TrackersBig](https://files.catbox.moe/2p0plb.png) ![TrackersSmol](https://files.catbox.moe/185uiy.png)  
  
Above is a comparison between the default and the 'Compact' widgets. Both have the same functionality.
### Commands
`/infusion`: opens/closes the main menu.  
`/infusionwidget` or `/infw`: opens placeholder tracker widgets for positioning configuration outside of a raid. Can not be used otherwise.
`/infusionclose` or `/infc`: closes the tracking widgets. Can be used only if closing the configuration widgets OR if the raid does not have any druids in it.
## Tips/Caveats
* If you disconnect or leave mid raid, the cooldowns **will reset**. This is unavoidable.
* It is likely that if you die and have to ghost run back while the raid is ongoing (read: they can't/won't res you and just continue pulling), you will miss CDs and cause the tracker to be inaccurate if they happen to use the spells during your runback. Try not to die, silly :>!
## Contributions
Welcome contributions of any kind, particularly those related to optimization. This was coded using Codex magic and a healthy dose of reviewing, but I'm nowhere near an expert in archaic 2004 Lua and can only do so much. If you read through and spot silly things that could be improved, let me know!  

Special thanks to **Hiromi** for helping test so much of this addon! Honorable mentions to all the druids in the pics as well that gave me innervates every time I whispered them xD.
## To-do
* ~add autoscan (join raid > autoscan > (no druids, display empty box) > refresh scan on join/leave)~
* bigwigs integration for resyncing in case of dc
