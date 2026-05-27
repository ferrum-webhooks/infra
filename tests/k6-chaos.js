import http from "k6/http";

export const options = {
  vus: 50,
  duration: "5m",
};

const BASE_URL = "http://gateway:8000";

export default function () {
  http.post(
    `${BASE_URL}/events`,
    JSON.stringify({
      payload: {
        message: "chaos-test",
      },
      event_type: "test",
    }),
    {
      headers: {
        "Content-Type": "application/json",
      },
    }
  );
}