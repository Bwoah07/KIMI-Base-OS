import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import org.squiddev.cobalt.LuaState;
import org.squiddev.cobalt.LuaThread;
import org.squiddev.cobalt.compiler.LuaC;
import org.squiddev.cobalt.function.LuaFunction;
import org.squiddev.cobalt.lib.CoreLibraries;
import org.squiddev.cobalt.lib.system.ResourceLoader;
import org.squiddev.cobalt.lib.system.SystemBaseLib;

public final class CobaltLuaRunner {
    private CobaltLuaRunner() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0) throw new IllegalArgumentException("Provide at least one Lua file");

        for (String value : args) {
            Path file = Path.of(value);
            LuaState syntaxState = new LuaState();
            try (InputStream input = Files.newInputStream(file)) {
                LuaC.compile(syntaxState, input, "@" + file);
            }
            System.out.println("Lua syntax OK: " + file);
        }

        if (args.length == 1) {
            LuaState runtime = new LuaState();
            CoreLibraries.standardGlobals(runtime);
            new SystemBaseLib(ResourceLoader.FILES, System.in, System.out).add(runtime);
            LuaFunction chunk = SystemBaseLib.loadFile(runtime, ResourceLoader.FILES, args[0]).first().checkFunction();
            LuaThread.runMain(runtime, chunk);
        }
    }
}
