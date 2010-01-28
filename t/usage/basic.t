use strict;
use warnings;
use Test::More tests => 4;
use Hailo;

my $hailo = Hailo->new(brain_resource => ':memory:');

while (<DATA>) {
    chomp;
    $hailo->learn($_);
}

is($hailo->reply("Gogogo"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");
is($hailo->reply("Naturally"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");
is($hailo->reply("Slamming"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");

my %reply;
for (1 .. 5000) {
    $reply{ $hailo->reply("that") } = 1;
}

is_deeply(
    \%reply,
    {
        "Ah, fusion, eh? I'll have to remember that." => 1,
        "I copy that." => 1,
        "I hear that." => 1,
        "I really have to remember that." => 1,
        "Oh, is that it?" => 1,
    },
    "Make sure we get every possible reply"
);

__DATA__
You want a piece of me, boy?
We gotta move!
Are you gonna give me orders?
Oh my god! He's whacked!
I vote we frag this commander.
How do I get out of this chicken *BEEP* outfit?!
You want a piece of me, boy?
Ahh...That's the stuff!
Ahh...Yea!
Commander.
Standin' by.
Jacked up and good to go.
Give me something to shoot.
Gogogo!
Let's move!
Outstanding!
Rock 'n roll!
Need a light?
Is something burning?
Haha, that's what I thought.
I love the smell of napalm.
Nothing like a good smoke!
Are you trying to get invited to my next barbecue?
Got any questions about propane?
Or, propane accessories?
Fire it up!
Yes?
You got my attention.
Wanna turn up the heat?
Naturally.
Slammin!
You've got it.
Let's burn.
Somebody call for an exterminator?
You called down the thunder...
Now reap the whirlwind.
Keep it up! I dare ya.
I'm about to overload my aggression inhibitors.
Ghost reporting.
I'm here.
Finally!
Call the shot.
I hear that.
I'm gone.
Never know what hit em.
I'm all over it.
All right, bring it on!
Something you wanted?
I don't have time to f*BEEP* around!
You keep pushing it boy.
And I'll scrap you along with the aliens!
What do YOU want?
Yeah?
I read ya, SIR.
Somethin' on your mind?
Yeah, I'm going.
I dig.
No problem!
Oh, is that it?
Goliath online.
MilSpec ED-209 online.
Checklist protocol initiated.
USDA Selected.
FDIC approved.
Checklist Completed. SOB.
Go ahead tac-com.
Com-link online.
Channel open.
Systems functional.
Acknowledged HQ.
Nav-com locked.
Confirmed.
Target designated.
Ready to roll out!
Singing the tune of Ride of the Valkyries
I'm about to drop the hammer!
And dispense some indiscriminate justice!
What is your major malfunction?
Yes sir!
Destination?
Identify target!
Orders sir!
Move it!
Proceedin'.
Delighted to, sir!
Absolutely!
SCV, good to go, sir.
I can't build it, something's in the way.
I can't build there.
Come again, Captain?
I'm not readin' you clearly.
You ain't from around here, are you?
I can't believe they put me in one of these things!
And now I gotta put up with this too?
I told em I was claustrophobic, I gotta get outta here!
Can I take your order?
When removing your overhead luggage, please be careful.
In case of a water landing, you may be used as a flotation device.
To hurl chunks, please use the vomit bag in front of you.
Go ahead, HQ.
I'm listenin'.
Destination?
Input coordinates.
In the pipe, five by five.
Hang on, we're in for some chop.
In transit, HQ.
Buckle up!
Strap yourselves in boys!
I copy that.
Wraith awaiting launch orders.
Last transmission breakin' up...come back...
I'm just curious...why am I so good?
I gotta get me one of these.
You know who the best starfighter in the fleet is?
Yours truly.
Everybody gotta die sometime, Red.
I am the invincible, that's right.
Go ahead commander.
Transmit coordinates.
Standin' by.
Reporting in.
Coordinates received.
Attack formation.
Roger.
Vector locked-in.
Battlecruiser operational.
Identify yourself!
Shields up! Weapons online!
Not equipped with shields? well then buckle up!
We are getting WAY behind schedule.
I really have to go...number one.
Battlecruiser reporting.
Receiving transmission.
Good day, commander.
Hailing frequencies open.
Make it happen.
Set a course.
Take it slow.
Engage!
Explorer reporting.
I like the cut of your jib!
E=MC...d'oh let me get my notepad.
Ah, fusion, eh? I'll have to remember that.
Eck, who set all these lab monkeys free?
I think we may have a gas leak!
Do any of you fools know how to shut off this infernal contraption?
Ah...the ship.... out of danger?
Ah, greetings command!
Transmit orders.
Receiving headquarters!
We have you on visual.
Let's roll!
Excellent!
Commencing!
Affirmative, sir.
Prepped and ready!
I've already checked you out commander.
You want another physical?
Turn your head an cough.
Ready for your sponge bath?
His EKG is flatlining! Get me a defib stat!
Clear! *bzzz*
He's dead, Jim.
Need medical attention?
Did someone page me?
State the nature of your medical emergency!
Where does it hurt?
Right away!
Stat!
I'm on the job!
On my way.
Valkyrie prepared.
This is very interesting...but stupid.
I have ways of blowing things up.
You're being very naughty.
Who's your mommy?
Blucher!
Need something destroyed?
I am eager to help.
Don't keep me waiting.
Achtung!
Of course my dear.
Perfect!
It's showtime!
Jawoll!
Achtung!
