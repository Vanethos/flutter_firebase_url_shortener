import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_url_shortner/firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WallOfSharingApp());
}

class WallOfSharingApp extends StatelessWidget {
  const WallOfSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wall Of Sharing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lime,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Post>> _posts;

  @override
  void initState() {
    super.initState();
    _posts = getPosts();
  }

  Future<List<Post>> getPosts() => FirebaseFirestore.instance
      .collection('posts')
      .get()
      .then((value) => value.docs)
      .then((docs) => docs
          .map<Post>(
            (doc) => Post.fromJson(
              doc.data(),
            ),
          )
          .toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(
              Icons.share,
            ),
            SizedBox(
              width: 12.0,
            ),
            Text("Wall Of Sharing"),
          ],
        ),
      ),
      body: FutureBuilder<List<Post>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "There has been an error",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.apply(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
            return Center(
              child: Text(
                "No posts yet!\nCreate the first one!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(snapshot.data![index].title),
                  subtitle: Text.rich(
                    TextSpan(
                      text: snapshot.data![index].shortUrl ??
                          snapshot.data![index].url,
                      mouseCursor: SystemMouseCursors.click,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                              Uri.parse(
                                snapshot.data![index].url,
                              ),
                            ),
                    ),
                    selectionColor: Colors.purple,
                  ),
                  shape: const StadiumBorder(
                      side: BorderSide(color: Colors.black26, width: 0.8)),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreatePostPage(),
            ),
          );
          _posts = getPosts();
          setState(() {});
        },
        tooltip: 'Create Post',
        child: const Icon(Icons.post_add),
      ),
    );
  }
}

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(
              Icons.share,
            ),
            SizedBox(
              width: 12.0,
            ),
            Text("Create Post"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600.0,
          ),
          child: Center(
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _titleController,
                    maxLines: 1,
                    decoration: const InputDecoration(
                      label: Text(
                        'Title',
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12.0,
                  ),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      label: Text(
                        'Url',
                      ),
                      errorStyle: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                    validator: (value) {
                      return Uri.tryParse(value ?? "") != null
                          ? null
                          : "Not a valid URL";
                    },
                  ),
                  const SizedBox(
                    height: 12.0,
                  ),
                  Builder(builder: (context) {
                    return ElevatedButton(
                      onPressed: () async {
                        if (!Form.of(context).validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill in all the fields"),
                            ),
                          );
                          return;
                        }
                        await _createPost(
                          _titleController.text,
                          _urlController.text,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text(
                        "CREATE POST",
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPost(String title, String url) async {
    await FirebaseFirestore.instance.collection('posts').add({
      'title': title,
      'url': url,
    });
  }
}

class Post {
  final String title;
  final String url;
  final String? shortUrl;

  Post({
    required this.title,
    required this.url,
    this.shortUrl,
  });

  static Post fromJson(Map<String, dynamic> json) {
    return Post(
      title: json["title"],
      url: json["url"],
      shortUrl: json["shortUrl"],
    );
  }
}
