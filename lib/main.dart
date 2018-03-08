import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';

final ThemeData defaultTheme = new ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
);

final googleSignIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;
final reference = FirebaseDatabase.instance.reference();
final surveysReference = reference.child('surveys');

void main() => runApp(new VotatoApp());

Future<Null> ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null)
    user = await googleSignIn.signInSilently();

  if (user == null) {
    user = await googleSignIn.signIn();
    analytics.logLogin();
  }

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
    await auth.signInWithGoogle(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
    );
  }
}

class VotatoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Votato",
      theme: defaultTheme,
      home: new VotatoScreen(),
    );
  }
}

class SurveyPage extends StatelessWidget{
  SurveyPage({this.survey});

  final survey;

  @override
  Widget build(BuildContext context) {
    debugPrint(survey.value['name']);
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(survey.value['name']),
      ),
      body: new Center(
        child: new Text('hola?')
      ),
    );
  }
}

class Survey extends StatelessWidget {
  Survey({this.animation, this.snapshot});
  final DataSnapshot snapshot;
  final Animation animation;

  handleSubmit() async {
    await ensureLoggedIn();

    final surveyId = snapshot.key;
    saveSurvey(surveyId: surveyId);
  }

  saveSurvey({ String surveyId }) {
    surveysReference.child(surveyId).remove();
    analytics.logEvent(name: 'delete_survey');
  }

  @override
  Widget build(context) {
    return new SizeTransition(
      sizeFactor: new CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut
      ),
      axisAlignment: 0.0,
      child: new Container(
        child: new Card(
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new ListTile(
                leading: new Icon(Icons.calendar_view_day),
                title: new Text(snapshot.value['name']),
                subtitle: new Text(snapshot.value['description']),
              ),
              new ButtonTheme.bar(
                child: new ButtonBar(
                  children: <Widget>[
                    new FlatButton(
                      child: const Text('Ver'),
                      onPressed: () {
                        Navigator.of(context).push(new PageRouteBuilder(
                          pageBuilder: (_, __, ___) => new SurveyPage(survey: snapshot),
                        ));
                      },
                    ),
                    new FlatButton(
                      child: const Text('Delete'),
                      textColor: Colors.red,
                      onPressed: handleSubmit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VotatoScreen extends StatefulWidget {
  @override
  State createState() => new VotatoScreenState();
}

class VotatoScreenState extends State<VotatoScreen> {
  final TextEditingController nameTextController = new TextEditingController();
  final TextEditingController descriptionTextController = new TextEditingController();

  @override
  Widget build(context) {

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('votato'),
        elevation: 0.0,
      ),
      body: new Column(children: <Widget>[
        new Flexible(
          child: new FirebaseAnimatedList(
            query: surveysReference,
            sort: (a, b) => b.key.compareTo(a.key),
            itemBuilder: (_, snapshot, animation, __) {
              return new Survey(
                snapshot: snapshot,
                animation: animation,
              );
            },
          ),
        ),
      ]),
      floatingActionButton: new FloatingActionButton(
        child: new Icon(
          Icons.add,
        ),
        onPressed: () {
          final dialog = new SimpleDialog(
            title: const Text('Nuevo encuesta'),
            children: <Widget>[
              new TextField(
                controller: nameTextController,
                onChanged: (text) => debugPrint(text),
                decoration: new InputDecoration(
                  hintText: "Nueva encuesta",
                  labelText: 'Nombre',
                  contentPadding: new EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
              new TextField(
                controller: descriptionTextController,
                onChanged: (text) => debugPrint(text),
                decoration: new InputDecoration(
                  hintText: "Encuesta wonita",
                  labelText: 'Description',
                  contentPadding: new EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
              new RaisedButton(
                child: new Text('save'),
                onPressed: () => this.handleSubmit(),
                color: Colors.blue,
                textColor: Colors.white,
              ),
            ],
          );

          showDialog(context: context, child: dialog);
        }
      ),
    );
  }

  handleSubmit() async {
    final name = nameTextController.text;
    final description = descriptionTextController.text;

    await ensureLoggedIn();
    saveSurvey(name: name, description: description);

    nameTextController.clear();
    descriptionTextController.clear();
  }

  saveSurvey({ String name, String description }) {
    surveysReference.push().set({
      'name': name,
      'description': description,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
    });
    analytics.logEvent(name: 'save_survey');
    Navigator.pop(context);
  }
}
