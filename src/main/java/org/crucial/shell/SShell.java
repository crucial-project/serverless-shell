package org.crucial.shell;

import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.core.internal.http.loader.DefaultSdkHttpClientBuilder;
import software.amazon.awssdk.http.SdkHttpClient;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.lambda.LambdaClient;
import software.amazon.awssdk.services.lambda.model.*;

import java.lang.Object.com.amazonaws.ClientConfiguration;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

public class SShell {

    public static final String ANSI_RESET = "\u001B[0m";
    public static final String ANSI_RED = "\u001B[31m";
    public static final String ALIASES = "source /var/task/aliases.sh;";

    public static final String ASYNC_FLAG = "--async";
    public static final String CMD_FLAG = "-c";
    public static final String SCRIPT_FLAG = "-f";
    public static final String USAGE = "usage: ("+CMD_FLAG+"|"+SCRIPT_FLAG+") "+"[--async] (command|script_file)";

    private List<String> cmd = null;

    private String script = null;

    private Properties properties = System.getProperties();
    private boolean asynchronous;
    private boolean debug;
    private LambdaClient lambdaClient;
    private ClientConfiguration lambdaClientConf;
    private String timeout;
    private String region;
    private String arn;

    public static void main(String[] args) {
        new SShell().doMain(args);
    }

    public void doMain(String[] args) {

        if (args.length<=1) {
            usage();
        }

        try {
            // Command
            StringBuilder stringBuilder = new StringBuilder();
            stringBuilder.append(ALIASES+" ");
            if (args[1].equals(ASYNC_FLAG)) asynchronous = true;
            switch (args[0]) {
                case CMD_FLAG:
                    for(String c : Arrays.copyOfRange(args, asynchronous ? 2 : 1, args.length)){
                        stringBuilder.append(c + " ");
                    }
                    break;
                case SCRIPT_FLAG:
                    Path file = Paths.get(asynchronous ? args[2]: args[1]);
                    Files.lines(file).filter(l -> !l.startsWith("#")).forEach(l -> stringBuilder.append(l));
                    break;
                default:
                    usage();
            }
            String command = stringBuilder.toString();

            // Configuration
            Path path = Paths.get(Config.CONFIG_FILE);
            InputStream is = new ByteArrayInputStream(Files.readAllBytes(path));
            properties.load(is);

            region = properties.containsKey(Config.AWS_LAMBDA_REGION) ?
                    properties.getProperty(Config.AWS_LAMBDA_REGION) : Config.AWS_LAMBDA_REGION_DEFAULT;
            timeout = properties.containsKey(Config.AWS_LAMBDA_CLIENT_TIMEOUT) ?
                    properties.getProperty(Config.AWS_LAMBDA_CLIENT_TIMEOUT) : Config.AWS_LAMBDA_CLIENT_TIMEOUT_DEFAULT;
            arn = properties.containsKey(Config.AWS_LAMBDA_FUNCTION_ARN) ?
                    properties.getProperty(Config.AWS_LAMBDA_FUNCTION_ARN) : Config.AWS_LAMBDA_FUNCTION_ARN_DEFAULT;
            debug = Boolean.parseBoolean(properties.containsKey(Config.AWS_LAMBDA_DEBUG) ?
                    properties.getProperty(Config.AWS_LAMBDA_DEBUG) : Config.AWS_LAMBDA_DEBUG_DEFAULT);
            asynchronous |= Boolean.parseBoolean(properties.containsKey(Config.AWS_LAMBDA_FUNCTION_ASYNC) ?
                    properties.getProperty(Config.AWS_LAMBDA_FUNCTION_ASYNC) : Config.AWS_LAMBDA_FUNCTION_ASYNC_DEFAULT);
            lambdaClient = LambdaClient
                    .builder()
                    .httpClientBuilder(
                            UrlConnectionHttpClient
                                    .builder()
                                    .connectionTimeout(
                                            Duration.ofSeconds(Long.parseLong(timeout))
                                    )
                    )
                    .region(Region.of(region))
                    .build();

            lambdaClientConf = new ClientConfiguration();
            lambdaClientConf
            .setConnectionTimeout(
                Duration.ofMillis(
                    Integer.parseInt(properties.containsKey(Config.AWS_LAMBDA_CLIENT_TIMEOUT) ? 
                    properties.getProperty(Config.AWS_LAMBDA_TIMEOUT) : Config.AWS_LAMBDA_CLIENT_TIMEOUT_DEFAULT)
                    )
                );

            // Invoke
            GetFunctionRequest gf = GetFunctionRequest.builder().functionName(arn).build();
            lambdaClient.getFunction(gf);

            InvokeRequest.Builder requestTuilder = InvokeRequest.builder();
            requestTuilder.functionName(arn);
            if (asynchronous) {
                requestTuilder.invocationType(InvocationType.EVENT);
            } else {
                requestTuilder.invocationType(InvocationType.REQUEST_RESPONSE);
            }
            requestTuilder.payload(SdkBytes.fromByteArray(Json.toJson(command).getBytes()));
            if (debug) {
                debug("[async="+asynchronous+"] "+command);
                requestTuilder.logType(LogType.TAIL);
            }

            // Response
            InvokeResponse response = lambdaClient.invoke(requestTuilder.build());
            assert response != null;
            if (debug) {
                if (!asynchronous) {
                    String log = new String(Base64.getDecoder().decode(response.logResult()));
                    for (String line : log.split(System.getProperty("line.separator"))) {
                        debug(line);
                    }
                }
            }

            String[] ret = Json.fromJson(response.payload().asUtf8String());
            if (ret != null) {
                System.err.print(ret[1]);
                System.out.print(ret[0]);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        System.exit(0);

    }

    private void usage(){
        System.err.println(USAGE);
        System.exit(-1);
    }

    private static void debug(String message){
        System.err.println(ANSI_RED + message + ANSI_RESET);
    }

}
