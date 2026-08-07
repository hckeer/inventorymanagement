### 1. Connect phone to Wi-Fi

  On the phone, open:

  Developer options → Wireless debugging

  Use the current pairing address/code shown there. These change periodically.

  /home/hckeer/Android/platform-tools/adb pair PHONE_IP:PAIR_PORT
  /home/hckeer/Android/platform-tools/adb connect PHONE_IP:CONNECT_PORT
  /home/hckeer/Android/platform-tools/adb devices -l

  Confirm the device shows as device.

  ### 2. Start ERPNext

  Terminal 1:

  cd /home/hckeer/work/erpnest/frappe_docker

  docker compose -f pwd.yml up -d \
    db redis-cache redis-queue backend frontend websocket \
    queue-short queue-long scheduler

  docker compose -f pwd.yml ps

  Check ERPNext:

  curl http://localhost:8080/api/method/ping

  Expected:

  {"message":"pong"}

  ### 3. Start MCP

  Terminal 2:

  cd /home/hckeer/work/inventorymanagement/mcp-server
  npm run dev

  Leave this terminal open.

  MCP should show:

  listening on http://0.0.0.0:3001

  ### 4. Start the Flutter app

  Terminal 3:

  cd /home/hckeer/work/inventorymanagement

  make health
  make run

  make run automatically uses the computer’s LAN IP for MCP. Currently it detected:

  http://192.168.1.74:3001

  Do not use localhost for the Android app.