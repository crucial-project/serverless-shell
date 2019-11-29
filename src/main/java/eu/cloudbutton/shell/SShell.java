package eu.cloudbutton.shell;

import eu.cloudbutton.executor.Config;
import eu.cloudbutton.executor.lambda.AWSLambdaExecutorService;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;
import java.util.concurrent.*;
import java.util.concurrent.Future;

public class SShell {

    public static final String ANSI_RESET = "\u001B[0m";
    public static final String ANSI_RED = "\u001B[31m";
    public static final String ASYNC_FLAG = "--async";
    public static final String ALIASES = "source /var/task/aliases.sh; "; // FIXME

    public static String readFile(String path, Charset encoding)
            throws IOException
    {
        byte[] encoded = Files.readAllBytes(Paths.get(path));
        return new String(encoded, encoding);
    }

    public static void main(String[] args) {

        Properties properties = System.getProperties();
        try (InputStream is = SShell.class.getClassLoader().getResourceAsStream(Config.CONFIG_FILE)) {
            properties.load(is);
        } catch (IOException e) {
            e.printStackTrace();
        }

        if (args.length>0 && args[0].equals(ASYNC_FLAG)){
            properties.setProperty(Config.AWS_LAMBDA_FUNCTION_ASYNC,"true");
        }

        ExecutorService service = new AWSLambdaExecutorService(properties);

        StringBuilder builder = new StringBuilder();
        builder.append(ALIASES);
        for (String str: args) {
            if (str.equals(ASYNC_FLAG)) continue;;
            builder.append(str);
            builder.append(" ");
        }
        String command = builder.toString();

        Future<String[]> future = service.submit((Serializable & Callable<String[]>)()-> {
            String stdout = "";
            String stderr = command+"\n";
            try {
                ProcessBuilder b = new ProcessBuilder("/bin/sh", "-c", command);
                Process p  = b.start();
                BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));
                BufferedReader stdError = new BufferedReader(new InputStreamReader(p.getErrorStream()));
                StringBuilder sibuilder = new StringBuilder();
                StringBuilder sobuilder = new StringBuilder();
                java.util.Scanner s = new java.util.Scanner(stdInput).useDelimiter("\\A");
                if (s.hasNext()) {
                    sibuilder.append(s.next());
                }
                s = new java.util.Scanner(stdError).useDelimiter("\\A");
                if (s.hasNext()) {
                    sobuilder.append(s.next());
                }
                p.waitFor();
                stdout += sibuilder.toString();
                stderr += sobuilder.toString();
            } catch (IOException| InterruptedException e) {
                stderr += e.getMessage();
            }
            String[] ret = {stdout,stderr};
            return ret;
        });

        try {
            String[] ret = future.get();
            if(ret!=null) {
                System.err.print(ANSI_RED + ret[1] + ANSI_RESET);
                System.out.print(ret[0]);
            }
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
        System.exit(0);
    }

}
