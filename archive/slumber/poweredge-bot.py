#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["discord.py"]
# ///

import discord
from discord.ext import commands
import subprocess

# replaced by deploy script with actual mac address, keys, and ips
mac_address = "MAC_ADDRESS"
bot_key = "BOT_KEY"


# create bot
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(
  command_prefix=commands.when_mentioned_or("!"),
  intents=intents
)


@bot.command()
async def up(ctx):
    result = subprocess.run(
        ["wakeonlan", mac_address],
        capture_output = True,
        text = True
    )
    await ctx.send("Magic packet sent")


bot.run(bot_key)
