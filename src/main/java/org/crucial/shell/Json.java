package org.crucial.shell;

import com.google.gson.Gson;


public class Json {

    private static Gson gson = new Gson();

    public static String toJson(String input) {
        return gson.toJson(input);
    }

    public static String[] fromJson(String input) {
        return gson.fromJson(input, String[].class);
    }



}
