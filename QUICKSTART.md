# ⚡ Quick Start - 2 Minutes to Running Graylog

## Step 1: Setup (automatic)

```bash
./setup.sh
```

Answer the questions:
- Administrator password: `Admin123!` (or any other)
- URL: `http://localhost:9000/` (leave default or change)

## Step 2: Start

```bash
make start
```

Or without Makefile:
```bash
docker-compose up -d
```

## Step 3: Wait ~60 Seconds

```bash
make logs-graylog
```

Wait until you see:
```
Graylog server up and running
```

## Step 4: Login

Open: **http://localhost:9000**

- Username: `admin`
- Password: (what you entered in setup.sh)

## Step 5: Add Your First Input

1. Go to **System → Inputs**
2. Select **Syslog UDP** from dropdown
3. Click **Launch new input**
4. Title: `Syslog`
5. Port: `1514`
6. **Save**

## Step 6: Send Your First Log

```bash
logger -n localhost -P 1514 "Hello Graylog!"
```

## Step 7: Search

Go to **Search** - you'll see your log!

---

## 🎉 Done!

Now you can:
- Add more inputs (GELF, Raw/Plaintext, JSON)
- Create a Dashboard
- Configure alerts
- Connect applications

## 📚 Next Steps

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - complete guide
- [README.md](README.md) - technical documentation

## 🆘 Problems?

```bash
# Check status
make status

# View logs
make logs

# Restart
make restart
```

## 🛑 Stop

```bash
make stop
```

## 🗑️ Remove (with data)

```bash
make clean-all
```

---

**Need more info?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) for advanced configuration!
