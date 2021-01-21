package org.crucial.shell;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

public class ShellHandler implements RequestHandler<String, String[]> {

    @Override
    public String[] handleRequest(String command, Context context) {
        String stdout = "";
        String stderr = "";
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
        } catch (IOException | InterruptedException e) {
            stderr += e.getMessage();
        }
        String[] ret = {stdout,stderr};
        return ret;
    }
}
