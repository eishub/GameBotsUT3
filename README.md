# GameBotsUT3
GameBotsUT3 is a mod for UT3 that allows characters in the game to be controlled via network sockets connected to other program

# How to build
1. Install UT3
2. Extract the `Src` folder of http://udn.epicgames.com/Files/UT3/Mods/UT3ScriptSource_1.5.rar to `\My Games\Unreal Tournament 3\UTGame\Src`
3. Clone this repo also in `\My Games\Unreal Tournament 3\UTGame\Src`
4. Add the following line to `\My Games\Unreal Tournament 3\UTGame\Config\UTEditor.ini` underneath `[ModPackages]`: `ModPackages=GameBotsUT3`
5. Run `UT3.exe make`

If everything went ok, the compiled GameBots3.u is located in the folder `My Games\Unreal Tournament 3\UTGame\Unpublished\CookedPC\Script`
