package devorama.twitter;

import java.io.IOException;
import java.io.InputStream;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Date;

import twitter4j.Status;
import twitter4j.Twitter;
import twitter4j.TwitterException;
import twitter4j.TwitterFactory;

public class TwitterTerrariumConnector implements Runnable {
	private final byte TEMPERATURE_UPPER_THRESHOLD_REACHED_EVENT = 0;
	private final byte LIGHTS_ON_EVENT = 1;
	private final byte LIGHTS_OFF_EVENT = 2;
	private final byte DOOR_OPEN_EVENT = 3;
	private final byte DOOR_CLOSED_EVENT = 4;
	private final byte HUMIDITY_LOWER_THRESHOLD_REACHED_EVENT = 5;
	private final byte TEMPERATURE_BACK_TO_NORMAL = 6;
	private final byte HUMIDITY_BACK_TO_NORMAL = 7;
	private Twitter twitter;
	private ServerSocket ss = null;
	private Socket s = null;

	public TwitterTerrariumConnector() {
		twitter = new TwitterFactory().getInstance();
	}

	public void postTweet(String message) {
		try {
			Status status = twitter.updateStatus(message);
			System.out.println("Successfully updated the status to ["
					+ status.getText() + "].");
		} catch (TwitterException e) {
			System.out.println("Problem while updating the status.");
			System.err.println(e);
		}
	}

	@Override
	public void run() {
		try {
			ss = new ServerSocket(80);
			while (true) {
				System.out.println("Waiting for Socket connection.");
				s = ss.accept();
				System.out.println("Socket connection accepted.");
				InputStream socketIn = s.getInputStream();
				byte[] b = new byte[1];
				while (socketIn.read(b) != -1) {
					System.out.println(b[0]);
					Date date = new Date(System.currentTimeMillis());
					switch (b[0]) {
					case TEMPERATURE_UPPER_THRESHOLD_REACHED_EVENT:
						postTweet("Terrarium temperature is getting really hot. " + date);
						break;
					case LIGHTS_ON_EVENT:
						postTweet("Terrarium lights have been turned on. " + date);
						break;
					case LIGHTS_OFF_EVENT:
						postTweet("Terrarium lights have been turned off. " + date);
						break;
					case DOOR_OPEN_EVENT:
						postTweet("Terrarium door was opened. " + date);
						break;
					case DOOR_CLOSED_EVENT:
						postTweet("Terrarium door was closed. " + date);
						break;
					case HUMIDITY_LOWER_THRESHOLD_REACHED_EVENT:
						postTweet("Terrarium humidity is getting really low. " + date);
						break;
					case TEMPERATURE_BACK_TO_NORMAL:
						postTweet("Terrarium temperature back to normal. "
								+ date);
						break;
					case HUMIDITY_BACK_TO_NORMAL:
						postTweet("Terrarium humidity back to normal. "
								+ date);
						break;
					}
				}
			}
		} catch (IOException e) {
			System.out
					.println("Problem while establishing connection to socket.");
			System.err.println(e);
		}

	}

	public static void main(String[] args) {
		new Thread(new TwitterTerrariumConnector()).start();
	}
}
