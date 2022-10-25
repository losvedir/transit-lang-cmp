import mill._, scalalib._

object app extends ScalaModule {
  def scalaVersion = "3.2.0"

  def ivyDeps = Agg(
    ivy"com.lihaoyi::cask:0.8.3",
    ivy"com.github.plokhotnyuk.jsoniter-scala::jsoniter-scala-core::2.17.6"
  )
  def compileIvyDeps = Agg(
    ivy"com.github.plokhotnyuk.jsoniter-scala::jsoniter-scala-macros::2.17.6"
  )

  object test extends Tests {
    def testFramework = "utest.runner.Framework"

    def ivyDeps = Agg(
      ivy"com.lihaoyi::utest::0.7.10",
      ivy"com.lihaoyi::requests::0.6.9"
    )
  }
}
