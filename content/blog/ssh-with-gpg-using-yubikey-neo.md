+++
title = "SSH with GPG using YubiKey NEO"
date = "2018-03-22T00:00:00Z"

#
# description is optional
#
# description = "An optional description for SEO. If not provided, an automatically created summary will be used."

tags = []
+++

A few months ago, I started to look for smart keys that could be used by Fresh8 Gaming to improve our overall developer security. I purchased a FIDO U2F YubiKey to give it a trial run, and found it pretty useful for the services that support it, Github and Google Apps being the two key ones.

Although I found the key useful, especially when my phone motherboard died and I lost my authenticator app, I definitely wanted to try out a more feature-rich key and see if I could move some of my developer security fundamentals to it. Enter the YubiKey NEO.

### What is YubiKey NEO?

A small, black, thin USB… thing.

Without going too much into a sales rant, the YubiKey NEO is an NFC and USB security key card, supporting one-time passwords, OpenPGP, PIV, and U2F, and can be used for a lot of different applications.

There are some clear advantages to having a hardware key over using things like an authenticator app.

- You don’t need any battery power to make it work, unlike a phone for SMS or authenticator apps.
- It’s waterproof, crush resistant, and very light.
- It also has hardware level security elements to guard your stuff; if a PIN is entered wrong 3 times, followed by a PUK to reset the PIN 3 times, the device goes back to factory settings, removing all stored data in the process. This prevents brute forcing even if the device is stolen.
- It’s much, much harder to hack a physical device; laptops and phones connected to the internet can always have the possibility of data breach. The YubiKey doesn’t allow for anything on the system to read from it’s file system, unlike files on your device if the right access levels are reached.

### Why I’ve written this

Once I got my key, I decided to jump straight in and play with SSH authentication to Github. It seemed like the simplest place to start, as there were a number of different blogs and guides available online. Unfortunately, I ran into a fair few issues with each, such as outdated GPG, different optional inputs, and just some oddities I thought worth documenting. Hopefully this will be helpful to some!

## So, let’s get on with it…

### Caveats

OK so, I’m not promising this will work for everyone, and to cover myself with that statement, here’s a list of versions I have installed for the systems and software I’m using throughout:

- macOS Sierra — 10.12.6
- YubiKey NEO — 2.0
- OpenPGP (on YubiKey) —1.0.11
- GPG — 2.2.5

I also factory reset my device by completely blocking myself out of it, and using the yubico-piv-tool, so I’m starting again with a completely fresh device.

### Preliminaries

A few things you’ll need to do before you dive in, or at least, I’d recommend you do:

- Buy a key. If you’re in the UK, Amazon is ~£1 cheaper than direct, and you can Amazon Prime it if you’re keen. Also for transparency, that link does have my affiliate stuff on it. I know, I’m a terrible person.
- Change the default PIN. This can be done via the YubiKey PIV Manager, which makes it pretty simple.
- Change the default and admin PIN via `gpg --change-pin`. There are some instructions on the GnuPG website on how to do this.

### Generate Keys

I’m going to be running though how to generate keys on the YubiKey itself, as opposed to local and uploading.

Firstly, fire up the GPG card edit tool:

```
gpg --card-edit
```

Within this, you’ll need to enter the admin mode:

```
admin
```

This should then feed back with `Admin commands are allowed`, which will allow you to start key generation:

```
generate
```

Running this will initially give you an option to create an off-card backup. If you decide to make one, ensure you store it securely, preferably offline. After this, you’ll get given options similar to previous key generation:

```
Make off-card backup of encryption key? (Y/n) YPlease specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0) 1y
Key expires at Thu 21 Mar 11:39:33 2019 GMT
Is this correct? (y/N) yGnuPG needs to construct a user ID to identify your key.Real name: Dom Udall
Email address: dom@dom.com
Comment: kaisen
You selected this USER-ID:
    "Dom Udall (kaisen) <dom@dom.com>"Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
gpg: Note: backup of card key saved to '/Users/dom/.gnupg/backupkey.gpg'
gpg: key DOMSGREATKEY marked as ultimately trusted
gpg: revocation certificate stored as '/Users/dom/.gnupg/openpgp-revocs.d/DOMSGREATKEYREVOKECERTIFICATE.rev'
public and secret key created and signed
```

During this process you’ll also get a prompt for a passphrase for your key (the Pinentry Mac software is already available on macOS Sierra and greater).
![Pinentry Mac](/static/image/ssh-with-gpg-using-yubikey-neo/1.png)

The card will now have your private and public keys stored, however to get your public key to be able to use it elsewhere, you need to run:

```
ssh-add -L
```

This will list the public SSH key identities you have on your machine. There should be one with a comment of `cardno:000<your yubikey serial>` which you can copy and use in your `authorized_keys` files, in Github, or elsewhere.

### Add Public Key to Github

For this run-through I’m going to use Github as a source to demonstrate SSH auth, mainly due to the fact it’s free, and your milage should vary less than if I demo with a VM. If you don’t have a Github account, just go to the homepage and you can register on the right hand side with minimal effort.

Once in, you can go to your key settings page to be able to add your public key:
![Github SSH Keys](/image/ssh-with-gpg-using-yubikey-neo/2.png)

Click “New SSH Key” in the top right to add your public key.

This will give you another form where you can add a custom title to your SSH key for displaying in the keys page, and paste in your public key:
![Github New SSH Key](/image/ssh-with-gpg-using-yubikey-neo/3.png)

Fill this in with your public key.

Once you’ve clicked “Add SSH key”, you will return to the keys page, and you should be able to see your newly added key at the bottom of the list:
![Github SSH Key Fingerprint](/image/ssh-with-gpg-using-yubikey-neo/4.png)

The key on the security page after it has been successfully added.

Before this can be tested, there are some things you need to do to ensure that your key is being picked up from the right place and used for SSH auth.

### GPG Agent for SSH Auth

Firstly, you need to enable SSH support within the GPG agent. This is done with a simple command flag within `~/.gnupg/gpg-agent.conf` and can be quickly added with:

```
echo enable-ssh-support >> ~/.gnupg/gpg-agent.conf
```

After that, you will need to start the GPG agent in your terminals to be able to get it connecting for SSH auth. To ensure this happens for every new terminal, you can add the following commands to your `~/.bashrc`, or other shell rc file (I’m using `zshrc`):

```
export SSH_AUTH_SOCK=\$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
```

Once you’ve run `source` on your rc file, or restarted your terminal app, you should have a `gpg-agent` running. To check this, you can just run `gpg-agent` and the output will state if it is running or not.

### Testing the Setup

> **Note:** For testing, I ensured my current SSH keys were commented out in my `~/.ssh/ssh_config file`, so that I wouldn’t get one of my current keys accidentally authorising, and giving a false positive result.

Now everything is in place, we can finally check with Github to see if it knows who we are just with the key on the YubiKey. It’s as simple as:

```
ssh git@github.com
```

If everything has worked (fingers crossed), you should get asked for your PIN, and see the following output once entered (with your own username):

```
PTY allocation request failed on channel 0
Hi domudall! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.
```

Remove the key and run the command again, and you should get this output:

```
Permission denied (publickey).
```

And that’s it! Now you should be able to add your public key to any `authorized_keys` files on servers, and SSH into them with your YubiKey as your SSH auth.

## Additional Bits

### Other Keys

A colleague showed me a post about other keys available and some of the shortcomings of the YubiKey NEO and 4. It’s definitely worth a read through, as it points out some previous security issues Yubico have encountered.
GPG Agent Configurations

The `gpg-agent` will ask for your pin after a timeout when trying to use SSH again, the default on OSX is 1800 seconds (30 minutes) per SSH connection creation, resetting on each use, and a max timeout of 7200 seconds (2 hours).

These settings can be changed in your `~/.gnupg/gpg-agent.conf` using the `default-cache-ttl-ssh` and `max-cache-ttl-ssh` parameters respectively. More options and information on agent settings can be found on the GnuPG website.

### Key Length

The YubiKey Neo only supports up to RSA 2048, if you wish to use RSA 4096, then you’ll need to purchase a YubiKey 4 Series instead. This doesn’t include NFC functionality, but does come in USB-C as well as USB-A varieties.

### I’m Not a Security Expert

I’m a developer at heart and, while I care a lot about security, I don’t claim to be an expert!

## Useful Links

Here are a number of sites I used to help compile this blog post. Please give them a read if you’d like to find out more!

- https://mikebeach.org/2017/09/07/yubikey-gpg-key-for-ssh-authentication/
- https://florin.myip.org/blog/easy-multifactor-authentication-ssh-using-yubikey-neo-tokens
- http://www.engineerbetter.com/blog/yubikey-ssh/
- https://0day.work/using-a-yubikey-for-gpg-and-ssh/
- https://ocramius.github.io/blog/yubikey-for-ssh-gpg-git-and-local-login/
- https://lwn.net/Articles/734767/
